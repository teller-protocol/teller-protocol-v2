import { randomUUID } from 'node:crypto'
import { z } from 'zod'
import type { McpServer } from '@modelcontextprotocol/sdk/server/mcp.js'
import {
  BUSINESS_ENTITY_TYPES, CA_PROVINCES, CREDIT_BANDS, CREDIT_BAND_IDS, EMPLOYMENT, EMPLOYMENT_IDS,
  LOAN_TYPES, LOAN_TYPE_IDS, PROHIBITED_BUSINESS_INDUSTRIES, RESIDENCY, RESIDENCY_IDS, TIMELINE,
  TIMELINE_IDS, US_STATES, type LoanTypeId,
} from '../catalog.js'
import type { Config } from '../config.js'
import {
  ACK_TTL_MS, DISCLOSURE_TEXT, DISCLOSURE_VERSION, mintAcknowledgement, scopeHashFor, type AckStore,
} from '../disclosure.js'
import { assertAmountWithinProductCap, assertSupportedCountry, PolicyError } from '../policy.js'
import type { PrequalAnswers, PrequalApiClient } from '../upstream/types.js'

export interface ToolDeps {
  config: Config
  client: PrequalApiClient
  ackStore: AckStore
  mode: 'live' | 'fixture'
}

const answersShape = {
  loanTypes: z.array(z.enum(LOAN_TYPE_IDS as [LoanTypeId, ...LoanTypeId[]]))
    .min(1)
    .describe('Which products the borrower wants. Use ids from get_prequal_schema; an invented id is dropped.'),
  country: z.string().describe('Borrower country, name or ISO-3166 alpha-2. Only US and CA are served today.'),
  amountUsd: z.number().positive().optional().describe('Requested amount normalized to USD.'),
  timeline: z.enum(TIMELINE_IDS as [string, ...string[]]).optional(),
  state: z.string().length(2).optional().describe('Two-letter US state code. Several lenders are state-gated.'),
  province: z.string().length(2).optional().describe('Two-letter Canadian province code.'),
  residency: z.enum(RESIDENCY_IDS as [string, ...string[]]).optional(),
  employment: z.enum(EMPLOYMENT_IDS as [string, ...string[]]).optional(),
  annualIncomeUsd: z.number().nonnegative().optional(),
  yearsAtJob: z.number().nonnegative().optional(),
  monthlyDebtUsd: z.number().nonnegative().optional(),
  credit: z.enum(CREDIT_BAND_IDS as [string, ...string[]]).optional().describe('Self-reported band. Never ask for an exact score.'),
  birthYear: z.number().int().min(1900).max(2020).optional().describe('Four-digit birth year only. Full dates of birth are refused.'),
  homeValueUsd: z.number().positive().optional(),
  mortgageBalanceUsd: z.number().nonnegative().optional(),
  vehicleValueUsd: z.number().positive().optional(),
  vehicleYear: z.number().int().optional(),
  business: z.object({
    entityType: z.enum(BUSINESS_ENTITY_TYPES as unknown as [string, ...string[]]).optional(),
    industry: z.string().optional(),
    annualRevenueUsd: z.number().nonnegative().optional(),
    monthsInBusiness: z.number().nonnegative().optional(),
    purpose: z.string().optional(),
  }).optional(),
}

const contactShape = {
  firstName: z.string().optional(),
  lastName: z.string().optional(),
  email: z.string().email().optional(),
  phone: z.string().optional().describe('E.164 or national format.'),
}

/**
 * Fields this connector refuses outright.
 *
 * These have to appear in the tool schema, not only in a runtime guard: the MCP
 * SDK validates arguments with zod, which STRIPS unknown keys. A forbidden key
 * that is merely absent from the schema is deleted silently and the call
 * succeeds, which tells the assistant nothing and leaves the identifier sitting
 * in its context. Declaring them makes the refusal visible and loud.
 */
const refused = (field: string) =>
  z
    .any()
    .optional()
    .refine((v) => v === undefined, {
      message:
        `This connector does not accept '${field}'. Government identifiers and bank credentials are ` +
        `collected on Teller's own secure form, never in a chat. Call check_prequal_route for the link.`,
    })

const refusedShape = {
  ssn: refused('ssn'),
  birthDate: refused('birthDate'),
  driverLicenseNumber: refused('driverLicenseNumber'),
  routingNumber: refused('routingNumber'),
  accountNumber: refused('accountNumber'),
  usShortTermDetail: refused('usShortTermDetail'),
  usHelocDetail: refused('usHelocDetail'),
  caLenderDetail: refused('caLenderDetail'),
}

function text(payload: unknown, summary: string) {
  return {
    content: [{ type: 'text' as const, text: summary }],
    structuredContent: { payload } as Record<string, unknown>,
  }
}

function fail(message: string, code: string) {
  return {
    isError: true,
    content: [{ type: 'text' as const, text: message }],
    structuredContent: { error: { code, message } } as Record<string, unknown>,
  }
}

function toAnswers(input: Record<string, unknown>, country: string): PrequalAnswers {
  const { loanTypes, ...rest } = input as { loanTypes: LoanTypeId[] } & Record<string, unknown>
  return { ...(rest as object), loanTypes, country } as PrequalAnswers
}

/** Builds the handoff link for US borrowers, carrying over everything safe to put in a URL. */
function buildFunnelUrl(base: string, answers: PrequalAnswers): string {
  const url = new URL(base)
  url.searchParams.set('products', answers.loanTypes.join(','))
  if (answers.amountUsd !== undefined) url.searchParams.set('amount', String(Math.round(answers.amountUsd)))
  if (answers.state) url.searchParams.set('state', answers.state.toUpperCase())
  if (answers.credit) url.searchParams.set('credit', answers.credit)
  if (answers.employment) url.searchParams.set('employment', answers.employment)
  if (answers.annualIncomeUsd !== undefined) url.searchParams.set('income', String(Math.round(answers.annualIncomeUsd)))
  if (answers.timeline) url.searchParams.set('timeline', answers.timeline)
  url.searchParams.set('src', 'muse-connector')
  return url.toString()
}

export function registerTools(server: McpServer, deps: ToolDeps): void {
  const { config, client, ackStore } = deps

  server.registerTool(
    'get_prequal_schema',
    {
      title: 'Get pre-qualification schema',
      description:
        'The products, answer keys and legal values this connector accepts. Call this before asking the ' +
        'borrower anything: loan-type ids are exact, and an id that is not in this list is dropped from the ' +
        'search. Free, reads nothing about the borrower.',
      inputSchema: {},
    },
    async () => {
      const payload = {
        loanTypes: LOAN_TYPES,
        creditBands: CREDIT_BANDS,
        employment: EMPLOYMENT,
        residency: RESIDENCY,
        timeline: TIMELINE,
        supportedCountries: config.supportedCountries,
        usStates: US_STATES,
        caProvinces: CA_PROVINCES,
        business: { entityTypes: BUSINESS_ENTITY_TYPES, prohibitedIndustries: PROHIBITED_BUSINESS_INDUSTRIES },
        neverCollected: {
          note:
            'This connector refuses government identifiers and bank credentials. Do not ask the borrower for ' +
            'a Social Security number, full date of birth, driver licence number, or bank routing/account ' +
            'numbers. Those are collected on Teller\'s own secure form.',
        },
      }
      return text(payload, `${LOAN_TYPES.length} loan products across ${config.supportedCountries.join(' and ')}.`)
    },
  )

  server.registerTool(
    'check_prequal_route',
    {
      title: 'Check where this application completes',
      description:
        'Decides whether the application finishes here or on Teller\'s own form, given the borrower country ' +
        'and products. Call it as soon as the country is known -- it determines which questions are still ' +
        'worth asking. This is about where the form lives, never about who can borrow.',
      inputSchema: {
        country: answersShape.country,
        loanTypes: answersShape.loanTypes.optional(),
      },
    },
    async ({ country, loanTypes }) => {
      try {
        const code = assertSupportedCountry(country, config.supportedCountries)
        if (code === 'US') {
          return text(
            {
              country: code,
              completion: 'handoff',
              reason:
                'US lenders require identifiers this connector will not carry in a chat (SSN, full date of ' +
                'birth, bank details). Collect the soft answers here, preview matches, then hand over the link.',
              funnelUrl: buildFunnelUrl(config.usFunnelBaseUrl, {
                loanTypes: (loanTypes ?? []) as LoanTypeId[], country: code,
              }),
              stillWorthAsking: ['loanTypes', 'amountUsd', 'state', 'credit', 'employment', 'annualIncomeUsd'],
            },
            'US application: preview here, then hand the borrower the Teller link to finish.',
          )
        }
        return text(
          {
            country: code,
            completion: 'in_place',
            stillWorthAsking: ['loanTypes', 'amountUsd', 'province', 'credit', 'employment', 'annualIncomeUsd'],
          },
          `${code} application completes here via submit_prequal.`,
        )
      } catch (err) {
        if (err instanceof PolicyError) return fail(err.message, err.code)
        throw err
      }
    },
  )

  server.registerTool(
    'preview_prequal_matches',
    {
      title: 'Preview lender matches',
      description:
        'Dry run. Reports which lenders would match so the borrower can change an answer and try again. ' +
        'Stores nothing and sends nothing to any lender. Always preview before submitting.',
      inputSchema: { ...answersShape, ...refusedShape },
    },
    async (input) => {
      try {
        const code = assertSupportedCountry(input.country, config.supportedCountries)
        assertAmountWithinProductCap(input.loanTypes, input.amountUsd)
        const answers = toAnswers(input as Record<string, unknown>, code)
        const result = await client.preview(answers)
        const summary = result.matches.length
          ? `${result.matches.length} lender(s) would match. Nothing has been sent -- this was a preview.`
          : 'No lenders match these answers yet. Nothing has been sent.'
        return text({ ...result, preview: true, country: code }, summary)
      } catch (err) {
        if (err instanceof PolicyError) return fail(err.message, err.code)
        throw err
      }
    },
  )

  server.registerTool(
    'get_prequal_disclosure',
    {
      title: 'Get the consent disclosure',
      description:
        'Returns the disclosure the borrower must agree to, plus a single-use acknowledgement id. Show the ' +
        'disclosure text VERBATIM -- do not summarise or paraphrase it -- and get an explicit yes from the ' +
        'borrower. submit_prequal will not run without the id this returns.',
      inputSchema: {
        loanTypes: answersShape.loanTypes,
        country: answersShape.country,
      },
    },
    async ({ loanTypes, country }) => {
      try {
        const code = assertSupportedCountry(country, config.supportedCountries)
        const ack = mintAcknowledgement(loanTypes, code)
        await ackStore.put(ack)
        return text(
          {
            disclosureText: DISCLOSURE_TEXT,
            disclosureVersion: DISCLOSURE_VERSION,
            disclosureAckId: ack.id,
            expiresInSeconds: Math.floor(ACK_TTL_MS / 1000),
            instruction:
              'Display disclosureText verbatim. If the borrower agrees, call submit_prequal with this ' +
              'disclosureAckId and consent: true. If they do not agree, do not submit.',
          },
          'Disclosure issued. Show it verbatim and get an explicit yes before submitting.',
        )
      } catch (err) {
        if (err instanceof PolicyError) return fail(err.message, err.code)
        throw err
      }
    },
  )

  server.registerTool(
    'submit_prequal',
    {
      title: 'Submit the pre-qualification',
      description:
        'Sends the lead to matched lenders. THIS CANNOT BE UNDONE -- a submitted lead cannot be recalled. ' +
        'Requires a live disclosureAckId from get_prequal_disclosure and the borrower\'s explicit consent. ' +
        'Never call this off the back of a preview alone; the borrower must say yes first.',
      inputSchema: {
        ...answersShape,
        ...contactShape,
        ...refusedShape,
        consent: z.literal(true).describe('Must be true, and must reflect an explicit yes from the borrower.'),
        disclosureAckId: z.string().uuid().describe('Single-use id from get_prequal_disclosure.'),
        clientSubmissionId: z.string().uuid().optional().describe('Pass a stable uuid to make retries idempotent.'),
      },
    },
    async (input) => {
      try {
        const { consent, disclosureAckId, clientSubmissionId, ...rest } = input
        const code = assertSupportedCountry(rest.country, config.supportedCountries)
        assertAmountWithinProductCap(rest.loanTypes, rest.amountUsd)

        const answers = toAnswers(rest as Record<string, unknown>, code)

        if (code === 'US') {
          return text(
            {
              completion: 'handoff',
              funnelUrl: buildFunnelUrl(config.usFunnelBaseUrl, answers),
              submitted: false,
              reason:
                'US applications are completed on Teller\'s own form so identifiers are never entered in a ' +
                'chat. The link carries the answers already given.',
            },
            'Not submitted. Hand the borrower this link to finish on Teller\'s secure form.',
          )
        }

        if (consent !== true) return fail('Borrower consent is required before submitting.', 'consent_required')

        const ack = await ackStore.take(disclosureAckId)
        if (!ack) {
          return fail(
            'That disclosure acknowledgement is unknown, already used or expired. Call get_prequal_disclosure ' +
              'again, show the text verbatim, and get a fresh yes.',
            'ack_invalid',
          )
        }
        if (ack.scopeHash !== scopeHashFor(answers.loanTypes, code)) {
          return fail(
            'The disclosure was acknowledged for a different set of products or country. Re-issue it for what ' +
              'is actually being submitted.',
            'ack_scope_mismatch',
          )
        }

        const result = await client.submit(answers, {
          consent: true,
          disclosureVersion: ack.disclosureVersion,
          acknowledgedAt: ack.acknowledgedAt,
          clientSubmissionId: clientSubmissionId ?? randomUUID(),
        })
        return text(
          { ...result, submitted: true },
          `Submitted to ${result.lenderCount} lender(s). Lead ${result.leadId}. This cannot be recalled.`,
        )
      } catch (err) {
        if (err instanceof PolicyError) return fail(err.message, err.code)
        throw err
      }
    },
  )

  server.registerTool(
    'get_prequal_status',
    {
      title: 'Get lead status',
      description: 'Where a submitted lead stands and which lenders have it.',
      inputSchema: { leadId: z.string().min(1) },
    },
    async ({ leadId }) => {
      const status = await client.status(leadId)
      return text(status, `Lead ${leadId}: ${status.status}, ${status.lenders.length} lender(s).`)
    },
  )
}

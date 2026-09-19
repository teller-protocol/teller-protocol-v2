import assert from 'node:assert/strict'
import { randomUUID } from 'node:crypto'
import { beforeEach, describe, it } from 'node:test'
import { Client } from '@modelcontextprotocol/sdk/client/index.js'
import { InMemoryTransport } from '@modelcontextprotocol/sdk/inMemory.js'
import { loadConfig } from '../src/config.js'
import { InMemoryAckStore } from '../src/disclosure.js'
import { buildServer } from '../src/server.js'
import { FixturePrequalClient } from '../src/upstream/fixture.js'

const config = loadConfig({ SUPPORTED_COUNTRIES: 'US,CA', US_FUNNEL_BASE_URL: 'https://teller.org/prequalify' } as NodeJS.ProcessEnv)

async function connect() {
  const ackStore = new InMemoryAckStore()
  const server = buildServer({ config, client: new FixturePrequalClient(), ackStore, mode: 'fixture' })
  const client = new Client({ name: 'test', version: '0' })
  const [clientTransport, serverTransport] = InMemoryTransport.createLinkedPair()
  await Promise.all([server.connect(serverTransport), client.connect(clientTransport)])
  return { client, server }
}

function payload(result: unknown): any {
  return (result as { structuredContent?: { payload?: unknown } }).structuredContent?.payload
}

function errorCode(result: unknown): string | undefined {
  return (result as { structuredContent?: { error?: { code?: string } } }).structuredContent?.error?.code
}

/** Schema violations come back as isError results, not thrown rejections. */
function isError(result: unknown): boolean {
  return (result as { isError?: boolean }).isError === true
}

function errorText(result: unknown): string {
  return ((result as { content?: { text?: string }[] }).content ?? []).map((c) => c.text ?? '').join(' ')
}

let ctx: Awaited<ReturnType<typeof connect>>
beforeEach(async () => {
  ctx = await connect()
})

describe('tool surface', () => {
  it('exposes exactly the six prequal tools', async () => {
    const { tools } = await ctx.client.listTools()
    assert.deepEqual(
      tools.map((t) => t.name).sort(),
      ['check_prequal_route', 'get_prequal_disclosure', 'get_prequal_schema', 'get_prequal_status', 'preview_prequal_matches', 'submit_prequal'],
    )
  })

  it('returns the catalog without asking for borrower data', async () => {
    const res = await ctx.client.callTool({ name: 'get_prequal_schema', arguments: {} })
    assert.equal(payload(res).loanTypes.length, 9)
    assert.deepEqual(payload(res).supportedCountries, ['US', 'CA'])
  })
})

describe('routing', () => {
  it('routes US borrowers to the funnel', async () => {
    const res = await ctx.client.callTool({ name: 'check_prequal_route', arguments: { country: 'United States', loanTypes: ['auto_purchase'] } })
    assert.equal(payload(res).completion, 'handoff')
    assert.match(payload(res).funnelUrl, /^https:\/\/teller\.org\/prequalify\?/)
  })

  it('completes Canadian applications in place', async () => {
    const res = await ctx.client.callTool({ name: 'check_prequal_route', arguments: { country: 'CA' } })
    assert.equal(payload(res).completion, 'in_place')
  })

  it('refuses an unsupported country', async () => {
    const res = await ctx.client.callTool({ name: 'check_prequal_route', arguments: { country: 'GB' } })
    assert.equal(errorCode(res), 'country_not_supported')
  })
})

describe('preview', () => {
  it('matches lenders and never marks itself submitted', async () => {
    const res = await ctx.client.callTool({
      name: 'preview_prequal_matches',
      arguments: { loanTypes: ['personal'], country: 'US', state: 'CA', credit: 'good', annualIncomeUsd: 80_000, amountUsd: 20_000 },
    })
    assert.equal(payload(res).preview, true)
    assert.ok(payload(res).matches.length > 0)
  })

  it('reports a state exclusion as a disqualifier', async () => {
    const res = await ctx.client.callTool({
      name: 'preview_prequal_matches',
      arguments: { loanTypes: ['personal'], country: 'US', state: 'NY', credit: 'fair', annualIncomeUsd: 30_000 },
    })
    assert.ok(payload(res).disqualifiers.some((d: string) => d.includes('NY')))
  })

  it('names the answers that would widen the match set', async () => {
    const res = await ctx.client.callTool({ name: 'preview_prequal_matches', arguments: { loanTypes: ['heloc'], country: 'US' } })
    assert.ok(payload(res).missingForBetterMatch.includes('homeValueUsd'))
  })

  it('rejects an amount above the product ceiling', async () => {
    const res = await ctx.client.callTool({ name: 'preview_prequal_matches', arguments: { loanTypes: ['personal'], country: 'CA', amountUsd: 500_000 } })
    assert.equal(errorCode(res), 'amount_above_cap')
  })
})

describe('consent gate', () => {
  it('refuses to submit without a valid acknowledgement', async () => {
    const res = await ctx.client.callTool({
      name: 'submit_prequal',
      arguments: { loanTypes: ['personal'], country: 'CA', consent: true, disclosureAckId: randomUUID() },
    })
    assert.equal(errorCode(res), 'ack_invalid')
  })

  it('refuses to reuse an acknowledgement', async () => {
    const disc = await ctx.client.callTool({ name: 'get_prequal_disclosure', arguments: { loanTypes: ['personal'], country: 'CA' } })
    const ackId = payload(disc).disclosureAckId
    const args = { loanTypes: ['personal'], country: 'CA', credit: 'good', annualIncomeUsd: 60_000, consent: true, disclosureAckId: ackId }
    const first = await ctx.client.callTool({ name: 'submit_prequal', arguments: args })
    assert.equal(payload(first).submitted, true)
    const second = await ctx.client.callTool({ name: 'submit_prequal', arguments: args })
    assert.equal(errorCode(second), 'ack_invalid')
  })

  it('refuses an acknowledgement minted for different products', async () => {
    const disc = await ctx.client.callTool({ name: 'get_prequal_disclosure', arguments: { loanTypes: ['personal'], country: 'CA' } })
    const res = await ctx.client.callTool({
      name: 'submit_prequal',
      arguments: { loanTypes: ['business'], country: 'CA', consent: true, disclosureAckId: payload(disc).disclosureAckId },
    })
    assert.equal(errorCode(res), 'ack_scope_mismatch')
  })

  it('returns the disclosure text verbatim with an expiry', async () => {
    const res = await ctx.client.callTool({ name: 'get_prequal_disclosure', arguments: { loanTypes: ['personal'], country: 'CA' } })
    assert.match(payload(res).disclosureText, /not an offer of credit/)
    assert.equal(payload(res).expiresInSeconds, 1800)
  })

  it('rejects consent: false at the schema boundary', async () => {
    const res = await ctx.client.callTool({
      name: 'submit_prequal',
      arguments: { loanTypes: ['personal'], country: 'CA', consent: false, disclosureAckId: randomUUID() },
    })
    assert.ok(isError(res))
    assert.match(errorText(res), /expected true at consent/)
  })
})

describe('submission', () => {
  it('hands US borrowers a prefilled link instead of submitting', async () => {
    const disc = await ctx.client.callTool({ name: 'get_prequal_disclosure', arguments: { loanTypes: ['auto_purchase'], country: 'US' } })
    const res = await ctx.client.callTool({
      name: 'submit_prequal',
      arguments: { loanTypes: ['auto_purchase'], country: 'US', state: 'TX', credit: 'good', amountUsd: 30_000, consent: true, disclosureAckId: payload(disc).disclosureAckId },
    })
    assert.equal(payload(res).submitted, false)
    assert.equal(payload(res).completion, 'handoff')
    const url = new URL(payload(res).funnelUrl)
    assert.equal(url.searchParams.get('state'), 'TX')
    assert.equal(url.searchParams.get('amount'), '30000')
    assert.equal(url.searchParams.get('src'), 'muse-connector')
  })

  it('is idempotent on a repeated clientSubmissionId', async () => {
    const submissionId = randomUUID()
    const leadIds: string[] = []
    for (let i = 0; i < 2; i++) {
      const disc = await ctx.client.callTool({ name: 'get_prequal_disclosure', arguments: { loanTypes: ['personal'], country: 'CA' } })
      const res = await ctx.client.callTool({
        name: 'submit_prequal',
        arguments: { loanTypes: ['personal'], country: 'CA', credit: 'good', annualIncomeUsd: 60_000, consent: true, disclosureAckId: payload(disc).disclosureAckId, clientSubmissionId: submissionId },
      })
      leadIds.push(payload(res).leadId)
    }
    assert.equal(leadIds[0], leadIds[1])
  })

  // Regression: zod strips unknown keys, so an identifier that is merely absent
  // from the schema was silently dropped and the lead submitted anyway.
  for (const field of ['ssn', 'routingNumber', 'accountNumber', 'driverLicenseNumber', 'birthDate', 'usShortTermDetail']) {
    it(`refuses a submission carrying ${field} instead of stripping it`, async () => {
      const disc = await ctx.client.callTool({ name: 'get_prequal_disclosure', arguments: { loanTypes: ['personal'], country: 'CA' } })
      const res = await ctx.client.callTool({
        name: 'submit_prequal',
        arguments: {
          loanTypes: ['personal'], country: 'CA', credit: 'good', annualIncomeUsd: 60_000,
          consent: true, disclosureAckId: payload(disc).disclosureAckId, [field]: 'x',
        },
      })
      assert.ok(isError(res), `${field} was accepted`)
      assert.equal(payload(res)?.submitted, undefined)
    })

    it(`refuses a preview carrying ${field}`, async () => {
      const res = await ctx.client.callTool({
        name: 'preview_prequal_matches',
        arguments: { loanTypes: ['personal'], country: 'CA', [field]: 'x' },
      })
      assert.ok(isError(res), `${field} was accepted`)
    })
  }

  it('reports status for a submitted lead', async () => {
    const disc = await ctx.client.callTool({ name: 'get_prequal_disclosure', arguments: { loanTypes: ['personal'], country: 'CA' } })
    const sub = await ctx.client.callTool({
      name: 'submit_prequal',
      arguments: { loanTypes: ['personal'], country: 'CA', credit: 'good', annualIncomeUsd: 60_000, consent: true, disclosureAckId: payload(disc).disclosureAckId },
    })
    const res = await ctx.client.callTool({ name: 'get_prequal_status', arguments: { leadId: payload(sub).leadId } })
    assert.equal(payload(res).status, 'routed')
  })
})

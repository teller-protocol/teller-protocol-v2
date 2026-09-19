import { LOAN_TYPES, type LoanTypeId } from './catalog.js'

/**
 * Field names this connector refuses to accept, ever.
 *
 * The lender-side schema has detail blocks (usShortTermDetail, usHelocDetail,
 * caLenderDetail) that carry government identifiers and bank credentials. Those
 * belong in a form on a page the borrower can see, not in an assistant
 * transcript that is relayed through a third-party agent runtime. US borrowers
 * are handed a funnel link instead -- see routeFor().
 */
export const FORBIDDEN_FIELDS = [
  'ssn',
  'socialSecurityNumber',
  'routingNumber',
  'accountNumber',
  'bankName',
  'accountType',
  'driverLicenseNumber',
  'driverLicenseState',
  'birthDate',
  'dateOfBirth',
  'dob',
  'nextPayDate',
  'usShortTermDetail',
  'usHelocDetail',
  'caLenderDetail',
] as const

const FORBIDDEN_LOOKUP = new Set<string>(FORBIDDEN_FIELDS.map((f) => f.toLowerCase()))

export class PolicyError extends Error {
  constructor(
    message: string,
    readonly code: string,
  ) {
    super(message)
    this.name = 'PolicyError'
  }
}

/**
 * Rejects the whole call if any forbidden identifier appears, at any depth.
 * Scrubbing silently would be worse: the borrower would believe the detail was
 * accepted and the agent would carry it in context regardless.
 */
export function assertNoForbiddenFields(value: unknown, path = 'answers'): void {
  if (value === null || typeof value !== 'object') return
  if (Array.isArray(value)) {
    value.forEach((item, i) => assertNoForbiddenFields(item, `${path}[${i}]`))
    return
  }
  for (const [key, child] of Object.entries(value as Record<string, unknown>)) {
    if (FORBIDDEN_LOOKUP.has(key.toLowerCase())) {
      throw new PolicyError(
        `This connector does not accept '${key}'. Government identifiers and bank ` +
          `credentials are collected on Teller's own secure form, never in a chat. ` +
          `Call check_prequal_route to get the link to hand the borrower.`,
        'forbidden_field',
      )
    }
    assertNoForbiddenFields(child, `${path}.${key}`)
  }
}

export function assertSupportedCountry(country: string, supported: string[]): string {
  const code = normalizeCountry(country)
  if (!code) throw new PolicyError(`Could not read '${country}' as a country.`, 'unknown_country')
  if (!supported.includes(code)) {
    throw new PolicyError(
      `Pre-qualification is not available in ${code} yet. Supported today: ${supported.join(', ')}.`,
      'country_not_supported',
    )
  }
  return code
}

const COUNTRY_ALIASES: Record<string, string> = {
  us: 'US', usa: 'US', 'united states': 'US', 'united states of america': 'US', america: 'US',
  ca: 'CA', can: 'CA', canada: 'CA',
}

export function normalizeCountry(input: string): string | undefined {
  const raw = input.trim().toLowerCase()
  if (!raw) return undefined
  if (COUNTRY_ALIASES[raw]) return COUNTRY_ALIASES[raw]
  if (/^[a-z]{2}$/.test(raw)) return raw.toUpperCase()
  return undefined
}

export function assertAmountWithinProductCap(loanTypes: LoanTypeId[], amountUsd: number | undefined): void {
  if (amountUsd === undefined) return
  if (!Number.isFinite(amountUsd) || amountUsd <= 0) {
    throw new PolicyError('amountUsd must be a positive number.', 'invalid_amount')
  }
  const cap = Math.max(...loanTypes.map((id) => LOAN_TYPES.find((t) => t.id === id)?.maxAmountUsd ?? 0))
  if (cap > 0 && amountUsd > cap) {
    throw new PolicyError(
      `$${amountUsd.toLocaleString('en-US')} is above the ceiling for the products selected ` +
        `($${cap.toLocaleString('en-US')}). Lower the amount or pick a different product.`,
      'amount_above_cap',
    )
  }
}

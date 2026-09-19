/**
 * Canonical pre-qualification catalog.
 *
 * Mirrors the lender-side schema. Loan-type ids are load-bearing: an id that is
 * not in this list is silently dropped by the matching engine, so tools validate
 * against these values rather than accepting free text.
 */

export const LOAN_TYPES = [
  { id: 'personal', label: 'Personal loan', sub: 'Unsecured cash for anything', maxAmountUsd: 50_000, secured: false },
  { id: 'business', label: 'Business loan', sub: 'Working capital or equipment', maxAmountUsd: 500_000, secured: false },
  { id: 'debt_consolidation', label: 'Card consolidation', sub: 'Pay off high-APR cards', maxAmountUsd: 50_000, secured: false },
  { id: 'student_refi', label: 'Student refi', sub: 'Refinance private or federal', maxAmountUsd: 250_000, secured: false },
  { id: 'home_purchase', label: 'Home purchase', sub: 'Buying a primary or second home', maxAmountUsd: 2_000_000, secured: true },
  { id: 'mortgage_refi', label: 'Mortgage refi', sub: 'Lower your rate or pull cash out', maxAmountUsd: 2_000_000, secured: true },
  { id: 'heloc', label: 'HELOC', sub: 'Tap your home equity', maxAmountUsd: 500_000, secured: true },
  { id: 'auto_purchase', label: 'Auto loan', sub: 'New or used vehicle', maxAmountUsd: 150_000, secured: true },
  { id: 'auto_refi', label: 'Auto refi', sub: 'Refinance an existing auto loan', maxAmountUsd: 150_000, secured: true },
] as const

export type LoanTypeId = (typeof LOAN_TYPES)[number]['id']
export const LOAN_TYPE_IDS = LOAN_TYPES.map((t) => t.id) as readonly LoanTypeId[]

export const CREDIT_BANDS = [
  { id: 'excellent', label: 'Excellent', sub: '750+' },
  { id: 'good', label: 'Good', sub: '700-749' },
  { id: 'fair', label: 'Fair', sub: '650-699' },
  { id: 'poor', label: 'Poor', sub: 'Below 650' },
  { id: 'unknown', label: "Don't know", sub: '' },
] as const
export const CREDIT_BAND_IDS = CREDIT_BANDS.map((b) => b.id)

export const EMPLOYMENT = [
  { id: 'w2', label: 'W-2 employee' },
  { id: 'self_employed', label: 'Self-employed' },
  { id: 'contractor', label: '1099 contractor' },
  { id: 'retired', label: 'Retired' },
  { id: 'student', label: 'Student' },
  { id: 'unemployed', label: 'Unemployed' },
] as const
export const EMPLOYMENT_IDS = EMPLOYMENT.map((e) => e.id)

export const RESIDENCY = [
  { id: 'citizen', label: 'Citizen' },
  { id: 'permanent_resident', label: 'Permanent resident' },
  { id: 'visa_holder', label: 'Visa holder' },
  { id: 'non_resident', label: 'Non-resident' },
] as const
export const RESIDENCY_IDS = RESIDENCY.map((r) => r.id)

export const TIMELINE = [
  { id: 'now', label: 'Right now' },
  { id: '1_3_months', label: '1-3 months' },
  { id: '3_6_months', label: '3-6 months' },
  { id: 'exploring', label: 'Just exploring' },
] as const
export const TIMELINE_IDS = TIMELINE.map((t) => t.id)

export const US_STATES = [
  'AL','AK','AZ','AR','CA','CO','CT','DE','DC','FL','GA','HI','ID','IL','IN','IA','KS','KY','LA','ME','MD','MA',
  'MI','MN','MS','MO','MT','NE','NV','NH','NJ','NM','NY','NC','ND','OH','OK','OR','PA','RI','SC','SD','TN','TX',
  'UT','VT','VA','WA','WV','WI','WY',
] as const

export const CA_PROVINCES = [
  'AB','BC','MB','NB','NL','NS','ON','PE','QC','SK','NT','NU','YT',
] as const

export const BUSINESS_ENTITY_TYPES = [
  'limited_liability_company','sole_proprietor','partnership','s_corporation','c_corporation','other',
] as const

/** Industries lenders will not fund. Surfaced so the agent can stop early rather than submitting a dead lead. */
export const PROHIBITED_BUSINESS_INDUSTRIES = [
  'finance_insurance','restricted','auto_dealer','nonprofit',
] as const

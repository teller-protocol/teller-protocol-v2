import type { LoanTypeId } from '../catalog.js'

/** The answer set this connector is willing to carry. Deliberately narrower than
 *  the full lender schema -- see src/policy.ts FORBIDDEN_FIELDS. */
export interface PrequalAnswers {
  loanTypes: LoanTypeId[]
  country: string
  amountUsd?: number
  amountLocal?: number
  amountCurrency?: string
  timeline?: string
  state?: string
  province?: string
  residency?: string
  employment?: string
  annualIncomeUsd?: number
  yearsAtJob?: number
  monthlyDebtUsd?: number
  credit?: string
  birthYear?: number
  firstName?: string
  lastName?: string
  email?: string
  phone?: string
  homeValueUsd?: number
  mortgageBalanceUsd?: number
  vehicleValueUsd?: number
  vehicleYear?: number
  business?: {
    entityType?: string
    industry?: string
    annualRevenueUsd?: number
    monthsInBusiness?: number
    purpose?: string
  }
}

export interface LenderMatch {
  lenderId: string
  lenderName: string
  productType: LoanTypeId
  estimatedAprRange?: { minPct: number; maxPct: number }
  estimatedAmountRange?: { minUsd: number; maxUsd: number }
  termMonths?: number[]
  notes?: string
}

export interface PreviewResult {
  matches: LenderMatch[]
  /** Answers that, if supplied, would widen the match set. */
  missingForBetterMatch: string[]
  disqualifiers: string[]
}

export interface SubmissionResult {
  leadId: string
  submittedAt: string
  lenderCount: number
  lenders: { lenderId: string; lenderName: string }[]
}

export interface LeadStatus {
  leadId: string
  status: 'received' | 'routed' | 'contacted' | 'closed'
  updatedAt: string
  lenders: { lenderId: string; lenderName: string; status: string }[]
}

export interface PrequalApiClient {
  preview(answers: PrequalAnswers): Promise<PreviewResult>
  submit(
    answers: PrequalAnswers,
    meta: { consent: true; disclosureVersion: string; acknowledgedAt: number; clientSubmissionId: string },
  ): Promise<SubmissionResult>
  status(leadId: string): Promise<LeadStatus>
}

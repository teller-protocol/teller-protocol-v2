import { randomUUID } from 'node:crypto'
import { PROHIBITED_BUSINESS_INDUSTRIES } from '../catalog.js'
import type { LeadStatus, LenderMatch, PrequalAnswers, PrequalApiClient, PreviewResult, SubmissionResult } from './types.js'

/**
 * Deterministic stand-in for the live API.
 *
 * It exists so the connector, its guards and the reviewer walkthrough can be
 * exercised end to end without a live lender integration -- nothing here ever
 * leaves the process and no real lead is created. Match logic is illustrative,
 * not underwriting.
 */

interface FixtureLender {
  lenderId: string
  lenderName: string
  products: string[]
  countries: string[]
  minCredit: number
  minIncomeUsd: number
  aprRange: { minPct: number; maxPct: number }
  amountRange: { minUsd: number; maxUsd: number }
  excludedStates?: string[]
}

const CREDIT_RANK: Record<string, number> = { excellent: 4, good: 3, fair: 2, poor: 1, unknown: 2 }

const LENDERS: FixtureLender[] = [
  { lenderId: 'fx-northgate', lenderName: 'Northgate Lending (sample)', products: ['personal', 'debt_consolidation'], countries: ['US'], minCredit: 3, minIncomeUsd: 45_000, aprRange: { minPct: 7.9, maxPct: 19.9 }, amountRange: { minUsd: 2_000, maxUsd: 50_000 } },
  { lenderId: 'fx-brightpath', lenderName: 'Brightpath Credit (sample)', products: ['personal', 'debt_consolidation', 'student_refi'], countries: ['US'], minCredit: 2, minIncomeUsd: 25_000, aprRange: { minPct: 11.5, maxPct: 29.9 }, amountRange: { minUsd: 1_000, maxUsd: 35_000 }, excludedStates: ['NY', 'WV'] },
  { lenderId: 'fx-keystone', lenderName: 'Keystone Home Loans (sample)', products: ['home_purchase', 'mortgage_refi', 'heloc'], countries: ['US'], minCredit: 3, minIncomeUsd: 60_000, aprRange: { minPct: 5.8, maxPct: 8.4 }, amountRange: { minUsd: 50_000, maxUsd: 2_000_000 } },
  { lenderId: 'fx-drivewell', lenderName: 'Drivewell Auto Finance (sample)', products: ['auto_purchase', 'auto_refi'], countries: ['US', 'CA'], minCredit: 2, minIncomeUsd: 30_000, aprRange: { minPct: 6.2, maxPct: 17.5 }, amountRange: { minUsd: 5_000, maxUsd: 150_000 } },
  { lenderId: 'fx-ironoak', lenderName: 'Ironoak Business Capital (sample)', products: ['business'], countries: ['US'], minCredit: 3, minIncomeUsd: 0, aprRange: { minPct: 9.0, maxPct: 24.0 }, amountRange: { minUsd: 25_000, maxUsd: 500_000 } },
  { lenderId: 'fx-maplebank', lenderName: 'Maple Trust (sample)', products: ['personal', 'debt_consolidation', 'auto_purchase'], countries: ['CA'], minCredit: 2, minIncomeUsd: 30_000, aprRange: { minPct: 8.9, maxPct: 26.9 }, amountRange: { minUsd: 2_000, maxUsd: 60_000 } },
]

export class FixturePrequalClient implements PrequalApiClient {
  private readonly submissions = new Map<string, SubmissionResult>()

  async preview(answers: PrequalAnswers): Promise<PreviewResult> {
    const country = answers.country.toUpperCase()
    const creditRank = CREDIT_RANK[answers.credit ?? 'unknown'] ?? 2
    const disqualifiers: string[] = []
    const matches: LenderMatch[] = []

    const businessIndustry = answers.business?.industry
    const industryBlocked =
      businessIndustry !== undefined &&
      (PROHIBITED_BUSINESS_INDUSTRIES as readonly string[]).includes(businessIndustry)
    if (industryBlocked) {
      disqualifiers.push(`Lenders in this network do not fund the '${businessIndustry}' industry.`)
    }

    for (const lender of LENDERS) {
      if (!lender.countries.includes(country)) continue
      const product = answers.loanTypes.find((t) => lender.products.includes(t))
      if (!product) continue
      if (product === 'business' && industryBlocked) continue
      if (creditRank < lender.minCredit) continue
      if (answers.annualIncomeUsd !== undefined && answers.annualIncomeUsd < lender.minIncomeUsd) continue
      if (answers.state && lender.excludedStates?.includes(answers.state.toUpperCase())) {
        disqualifiers.push(`${lender.lenderName} does not lend in ${answers.state.toUpperCase()}.`)
        continue
      }
      if (answers.amountUsd !== undefined && answers.amountUsd > lender.amountRange.maxUsd) continue

      matches.push({
        lenderId: lender.lenderId,
        lenderName: lender.lenderName,
        productType: product,
        estimatedAprRange: lender.aprRange,
        estimatedAmountRange: lender.amountRange,
        termMonths: [24, 36, 48, 60],
        notes: 'Sample lender. Estimates are illustrative, not an offer of credit.',
      })
    }

    const missing: string[] = []
    if (answers.credit === undefined) missing.push('credit')
    if (answers.annualIncomeUsd === undefined) missing.push('annualIncomeUsd')
    if (answers.employment === undefined) missing.push('employment')
    if (country === 'US' && answers.state === undefined) missing.push('state')
    if (answers.loanTypes.some((t) => t === 'heloc' || t === 'mortgage_refi')) {
      if (answers.homeValueUsd === undefined) missing.push('homeValueUsd')
      if (answers.mortgageBalanceUsd === undefined) missing.push('mortgageBalanceUsd')
    }
    if (answers.loanTypes.includes('auto_refi')) {
      if (answers.vehicleValueUsd === undefined) missing.push('vehicleValueUsd')
      if (answers.vehicleYear === undefined) missing.push('vehicleYear')
    }

    return { matches, missingForBetterMatch: missing, disqualifiers }
  }

  async submit(
    answers: PrequalAnswers,
    meta: { clientSubmissionId: string },
  ): Promise<SubmissionResult> {
    const existing = this.submissions.get(meta.clientSubmissionId)
    if (existing) return existing

    const { matches } = await this.preview(answers)
    const result: SubmissionResult = {
      leadId: `fx_lead_${randomUUID().slice(0, 12)}`,
      submittedAt: new Date().toISOString(),
      lenderCount: matches.length,
      lenders: matches.map((m) => ({ lenderId: m.lenderId, lenderName: m.lenderName })),
    }
    this.submissions.set(meta.clientSubmissionId, result)
    return result
  }

  async status(leadId: string): Promise<LeadStatus> {
    const found = [...this.submissions.values()].find((s) => s.leadId === leadId)
    if (!found) {
      return { leadId, status: 'closed', updatedAt: new Date().toISOString(), lenders: [] }
    }
    return {
      leadId,
      status: 'routed',
      updatedAt: found.submittedAt,
      lenders: found.lenders.map((l) => ({ ...l, status: 'routed' })),
    }
  }
}

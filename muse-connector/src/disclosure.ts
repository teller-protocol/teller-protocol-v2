import { createHash, randomUUID } from 'node:crypto'

/**
 * Consent handling.
 *
 * The lender-side schema is explicit that the integrating application must
 * collect the borrower's consent before a lead is submitted. Here the
 * integrating application is an assistant, so consent has to be an explicit
 * affirmative from the borrower against disclosure text this server returned --
 * never text the model wrote. submit_prequal will not run without a live
 * acknowledgement id produced by get_prequal_disclosure.
 */

/** Rendered by the assistant verbatim. Legal owns this string; do not paraphrase it. */
export const DISCLOSURE_TEXT = `By continuing you agree that Teller may share the information you have
provided with lenders and lending partners that match your request, and that those lenders may contact
you by phone, email or SMS about credit products -- including by automated dialling system or prerecorded
message -- at the number you provided, even if that number is on a do-not-call list. Consent is not a
condition of any purchase, and you may revoke it at any time.

A pre-qualification is not an offer of credit, not a commitment to lend, and not a guarantee of approval,
rate or amount. Pre-qualification uses a soft credit inquiry that does not affect your credit score; a
lender you proceed with may later run a hard inquiry, which can. Actual rates and terms depend on the
lender's own underwriting.

Submitting is final: a lead cannot be recalled once it reaches a lender.`

export const DISCLOSURE_VERSION = '2026-09-19.1'

export interface Acknowledgement {
  id: string
  /** Binds the ack to the exact request it was shown for. */
  scopeHash: string
  disclosureVersion: string
  acknowledgedAt: number
  expiresAt: number
}

export interface AckStore {
  put(ack: Acknowledgement): Promise<void>
  take(id: string): Promise<Acknowledgement | undefined>
}

/**
 * Single-process store. Fine for one instance; a multi-instance deployment must
 * swap in a shared store (Redis) or consent will fail across pods.
 */
export class InMemoryAckStore implements AckStore {
  private readonly acks = new Map<string, Acknowledgement>()

  async put(ack: Acknowledgement): Promise<void> {
    this.acks.set(ack.id, ack)
  }

  /** Single-use: taking an ack removes it, so one consent cannot fund two submissions. */
  async take(id: string): Promise<Acknowledgement | undefined> {
    const ack = this.acks.get(id)
    if (!ack) return undefined
    this.acks.delete(id)
    if (ack.expiresAt < Date.now()) return undefined
    return ack
  }
}

export const ACK_TTL_MS = 30 * 60 * 1000

export function scopeHashFor(loanTypes: readonly string[], country: string): string {
  return createHash('sha256').update(`${[...loanTypes].sort().join(',')}|${country}`).digest('hex').slice(0, 32)
}

export function mintAcknowledgement(loanTypes: readonly string[], country: string): Acknowledgement {
  const now = Date.now()
  return {
    id: randomUUID(),
    scopeHash: scopeHashFor(loanTypes, country),
    disclosureVersion: DISCLOSURE_VERSION,
    acknowledgedAt: now,
    expiresAt: now + ACK_TTL_MS,
  }
}

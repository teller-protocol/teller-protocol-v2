import type { Config } from '../config.js'
import { assertNoForbiddenFields } from '../policy.js'
import { FixturePrequalClient } from './fixture.js'
import type { LeadStatus, PrequalAnswers, PrequalApiClient, PreviewResult, SubmissionResult } from './types.js'

export class UpstreamError extends Error {
  constructor(
    message: string,
    readonly status: number,
  ) {
    super(message)
    this.name = 'UpstreamError'
  }
}

/**
 * Live backend.
 *
 * INTEGRATION SEAM -- this is the only file that needs to change when the real
 * pre-qualification API is available. The paths below are the contract this
 * connector expects; confirm them against the service before going live.
 */
export class HttpPrequalClient implements PrequalApiClient {
  constructor(
    private readonly baseUrl: string,
    private readonly apiKey: string | undefined,
    private readonly timeoutMs = 20_000,
  ) {}

  private async call<T>(path: string, init: RequestInit): Promise<T> {
    const controller = new AbortController()
    const timer = setTimeout(() => controller.abort(), this.timeoutMs)
    try {
      const res = await fetch(`${this.baseUrl}${path}`, {
        ...init,
        signal: controller.signal,
        headers: {
          'content-type': 'application/json',
          accept: 'application/json',
          ...(this.apiKey ? { authorization: `Bearer ${this.apiKey}` } : {}),
          ...init.headers,
        },
      })
      if (!res.ok) {
        const body = await res.text().catch(() => '')
        throw new UpstreamError(`Pre-qualification API returned ${res.status}: ${body.slice(0, 400)}`, res.status)
      }
      return (await res.json()) as T
    } finally {
      clearTimeout(timer)
    }
  }

  preview(answers: PrequalAnswers): Promise<PreviewResult> {
    return this.call<PreviewResult>('/preview', { method: 'POST', body: JSON.stringify({ answers }) })
  }

  submit(
    answers: PrequalAnswers,
    meta: { consent: true; disclosureVersion: string; acknowledgedAt: number; clientSubmissionId: string },
  ): Promise<SubmissionResult> {
    return this.call<SubmissionResult>('/submissions', {
      method: 'POST',
      body: JSON.stringify({ answers, ...meta }),
    })
  }

  status(leadId: string): Promise<LeadStatus> {
    return this.call<LeadStatus>(`/submissions/${encodeURIComponent(leadId)}`, { method: 'GET' })
  }
}

/**
 * Last line of defence before anything leaves this process.
 *
 * The tool schemas already refuse government identifiers at the boundary. This
 * re-checks the assembled payload at any depth, so a future code path that
 * builds answers from somewhere other than a tool call cannot quietly put an
 * identifier on the wire.
 */
export class GuardedPrequalClient implements PrequalApiClient {
  constructor(private readonly inner: PrequalApiClient) {}

  // async so a guard violation surfaces as a rejection, never a synchronous throw.
  async preview(answers: PrequalAnswers): Promise<PreviewResult> {
    assertNoForbiddenFields(answers)
    return this.inner.preview(answers)
  }

  async submit(
    answers: PrequalAnswers,
    meta: { consent: true; disclosureVersion: string; acknowledgedAt: number; clientSubmissionId: string },
  ): Promise<SubmissionResult> {
    assertNoForbiddenFields(answers)
    return this.inner.submit(answers, meta)
  }

  async status(leadId: string): Promise<LeadStatus> {
    return this.inner.status(leadId)
  }
}

export function createPrequalClient(config: Config): { client: PrequalApiClient; mode: 'live' | 'fixture' } {
  if (config.prequalApiBaseUrl) {
    return {
      client: new GuardedPrequalClient(new HttpPrequalClient(config.prequalApiBaseUrl, config.prequalApiKey)),
      mode: 'live',
    }
  }
  return { client: new GuardedPrequalClient(new FixturePrequalClient()), mode: 'fixture' }
}

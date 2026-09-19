# Open items before we can submit

## Blocking — the form does not exist yet

As of 2026-09-19, `https://muse.ai/platform` describes the review pipeline but
the **"Submit a connector" button links back to the same page**
(`<a href="/platform">`). There is no form, no mailto and no developer portal.
Every plausible route — `/platform/submit`, `/platform/apply`,
`/platform/developers`, `/developers`, `/connectors`, `/platform/docs`, `/docs` —
returns a 307 redirect. The sitemap lists four URLs (`/`, `/privacy`, `/terms`,
`/support`) and does not include `/platform`.

**Action:** watch the page for the button going live. Everything in this folder
is ready to paste when it does.

**Meanwhile:** Muse can attach a hosted MCP server over streamable HTTP without
a directory listing. Shipping the endpoint is not blocked on Meta.

## Blocking — needs a decision from Teller

| # | Item | Why it blocks |
|---|---|---|
| 1 | **Upstream API contract.** Teller has no public pre-qualification REST API yet. | The connector runs on a fixture backend until `src/upstream/client.ts` is pointed at a real endpoint. One file, three methods — the contract it expects is documented there. |
| 2 | **Hostname.** `mcp.teller.org`? | Goes in the submission and in every user-facing reference. |
| 3 | **Legal entity name** on the disclosure and the form. | Reviewers verify the connector's identity against a real entity. |
| 4 | **Support channel** — an email or form. | A Discord invite alone is unlikely to satisfy review. |
| 5 | **Public privacy policy and ToS URLs.** | Required fields. |
| 6 | **Lead retention period** and deletion process. | Required for the data-handling answer. |

## Blocking — needs counsel

| # | Item |
|---|---|
| 7 | Sign-off on the disclosure text in `src/disclosure.ts`. It is a drafting starting point, written to be reviewed, not shipped as-is. |
| 8 | Lead generator of record; state lead-gen / broker licensing; states to exclude. |
| 9 | TCPA consent sufficiency for automated contact; E-SIGN for electronic consent. |
| 10 | Canadian equivalents — CASL, provincial rules. |

## Non-blocking — decided, worth revisiting

- **Scope.** Six tools, prequalification only. Deliberately not the crypto
  borrowing product: different audience, more review risk, and it does not match
  the listing.
- **Markets.** US + CA at launch. Everything else returns a clean refusal.
- **US flow.** Preview in chat, complete on Teller's form. This is what keeps
  SSNs and bank details out of an agent transcript.
- **Short-term / small-dollar US lending.** Excluded entirely.
- **Auth.** None. Prequalification needs no account and no wallet, and requiring
  one would make the connector unusable for Muse's audience.

## Rate limiting

Not yet implemented — `submit_prequal` needs per-IP and per-session limits
before this is exposed publicly. Idempotency via `clientSubmissionId` is in
place, so retries cannot duplicate a lead, but that is not abuse protection.

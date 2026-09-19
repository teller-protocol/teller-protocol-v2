# Step 02 — Technical detail for review

## Integration shape

Hosted MCP server over **streamable HTTP**. Muse connects to it directly; there
is nothing for the user to install, and no local process.

| | |
|---|---|
| Endpoint | `POST https://mcp.teller.org/mcp` **[CONFIRM — final hostname]** |
| Transport | Streamable HTTP, stateless (no session pinning, no sticky routing) |
| Health check | `GET /healthz` |
| Protocol version | MCP `2025-06-18` |
| SDK | `@modelcontextprotocol/sdk` ^1.26 |
| Auth to the connector | None. Prequalification needs no account, no wallet, no API key. |
| Auth to upstream | Server-side bearer credential, held by the connector, never exposed to the agent or the user. |

Because the connector needs no user credential, there is nothing for Muse's
Secure Credentials Store to hold and nothing for Sentinel to inject. The
connector cannot act on a user's behalf anywhere; it can only answer questions
and, on explicit confirmation, submit a lead the user typed themselves.

## Tool inventory

| Tool | Writes? | Description |
|---|---|---|
| `get_prequal_schema` | No | Products, answer keys and legal values. Takes no borrower data. |
| `check_prequal_route` | No | Whether the application completes in-chat or on Teller's own form. |
| `preview_prequal_matches` | No | Dry run. Stores nothing, sends nothing to any lender. |
| `get_prequal_disclosure` | No | Returns the consent disclosure verbatim plus a single-use acknowledgement id. |
| `submit_prequal` | **Yes** | The only writing tool. Routes a lead to matched lenders. Irreversible. |
| `get_prequal_status` | No | Status of a lead already submitted. |

Exactly one tool has a side effect, and it is gated (see `03-data-handling.md`).

## Rate limiting and abuse

- **[CONFIRM]** per-IP and per-session limits on `submit_prequal`.
- `clientSubmissionId` makes retries idempotent, so a network retry cannot
  produce a duplicate lead.
- Disclosure acknowledgements are single-use and expire after 30 minutes.

## Deployment notes

The consent acknowledgement store is in-process by default. A multi-instance
deployment **must** back it with a shared store (Redis) or consent will fail
when a submission lands on a different instance than the disclosure. See
`src/disclosure.ts`.

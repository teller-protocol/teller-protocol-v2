# Teller pre-qualification MCP connector

A hosted MCP server that lets an assistant help someone pre-qualify for
personal, business, home and auto loans. Built for the Muse connector directory,
but it is a plain streamable-HTTP MCP server and works with any MCP client.

    Teller — Prequalify for personal, business, home, and auto loans

## Quick start

    npm install
    npm test          # 53 tests
    npm start         # listens on :8080, POST /mcp

With no `PREQUAL_API_BASE_URL` set it runs against a built-in fixture lender
set: nothing leaves the process and no lead reaches a real lender. `GET /healthz`
reports which backend is live.

    curl -s -X POST http://127.0.0.1:8080/mcp \
      -H 'content-type: application/json' \
      -H 'accept: application/json, text/event-stream' \
      -d '{"jsonrpc":"2.0","id":1,"method":"tools/list","params":{}}'

## Tools

| Tool | Writes? | |
|---|---|---|
| `get_prequal_schema` | No | Products, answer keys, legal values |
| `check_prequal_route` | No | Completes in chat, or on Teller's form? |
| `preview_prequal_matches` | No | Dry run — stores nothing, sends nothing |
| `get_prequal_disclosure` | No | Consent text + single-use acknowledgement |
| `submit_prequal` | **Yes** | Routes the lead. Irreversible. |
| `get_prequal_status` | No | Status of a submitted lead |

## The two guarantees this server makes

**1. It will not carry government identifiers or bank credentials.**
`ssn`, `birthDate`, `driverLicenseNumber`, `routingNumber`, `accountNumber` and
the lender detail blocks are declared in the tool schema and rejected with an
explanation. They are refused loudly rather than stripped silently — a stripped
field tells the assistant nothing and leaves the identifier in its context.
`GuardedPrequalClient` re-checks the assembled payload at any depth before
anything leaves the process. US borrowers are handed a pre-filled link to
Teller's own form instead.

**2. No lead is submitted without scoped, explicit, single-use consent.**
`submit_prequal` requires `consent: true` as a schema literal *and* a live
acknowledgement from `get_prequal_disclosure`, hashed against the exact products
and country it was shown for, expiring in 30 minutes, usable once.

Both are covered by tests. See `submission/03-data-handling.md`.

## Layout

    src/
      index.ts              HTTP listener, stateless streamable HTTP transport
      server.ts             McpServer + agent instructions
      tools/index.ts        the six tools
      catalog.ts            products, credit bands, employment, regions
      policy.ts             forbidden fields, country gate, amount caps
      disclosure.ts         consent text, acknowledgement minting and store
      upstream/
        client.ts           INTEGRATION SEAM — point this at the real API
        fixture.ts          deterministic stand-in, no network
    submission/             the Muse submission package
    test/                   53 tests

## Wiring up the real backend

`src/upstream/client.ts` is the only file that changes. Set
`PREQUAL_API_BASE_URL` (and `PREQUAL_API_KEY`) and the fixture backend is
replaced by `HttpPrequalClient`. The three endpoints it expects — `POST /preview`,
`POST /submissions`, `GET /submissions/:id` — are documented there; confirm them
against the service before going live.

## Deployment

Stateless: no session pinning, no sticky routing. The one piece of cross-request
state is the consent acknowledgement store, which is **in-process by default**.
A multi-instance deployment must back it with Redis or consent will fail when a
submission lands on a different instance than the disclosure. See
`src/disclosure.ts`.

Rate limiting on `submit_prequal` is not yet implemented and is required before
public exposure.

## Status

Not yet submitted to Muse — the submission form does not exist yet. See
`submission/05-open-items.md`.

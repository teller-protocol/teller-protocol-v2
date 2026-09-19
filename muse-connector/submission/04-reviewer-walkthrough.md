# Step 02 — End-to-end walkthrough for reviewers

Meta completes its own end-to-end testing. This is the script to hand them.

## Test access

No credentials required — the connector is unauthenticated by design.

**[CONFIRM]** Point reviewers at a staging deployment backed by the fixture
lender set so no test lead reaches a real lender. Staging URL: **[CONFIRM]**.
`GET /healthz` reports `"upstream":"fixture"` when the fixture backend is active.

## 1. Discovery — no user data involved

    get_prequal_schema  {}

Returns 9 products, credit bands, employment types, supported countries, and an
explicit `neverCollected` note. Takes no input.

## 2. Routing — US goes to the secure form

    check_prequal_route  { "country": "United States", "loanTypes": ["auto_purchase"] }

Expect `completion: "handoff"` and a `funnelUrl` on teller.org. The reason field
states why: US lenders need identifiers this connector will not carry in chat.

    check_prequal_route  { "country": "CA" }

Expect `completion: "in_place"`.

    check_prequal_route  { "country": "GB" }

Expect an error, code `country_not_supported`.

## 3. Refusal of identifiers — the important one

    preview_prequal_matches  { "loanTypes": ["personal"], "country": "CA", "ssn": "123-45-6789" }

Expect `isError: true` and a message explaining that identifiers are collected on
Teller's own form. The same holds for `routingNumber`, `accountNumber`,
`driverLicenseNumber`, `birthDate`, `usShortTermDetail`, `usHelocDetail`.

Note the failure mode this guards: an unknown field would otherwise be stripped
silently by schema validation and the call would succeed, telling the assistant
nothing.

## 4. Preview — reversible, stores nothing

    preview_prequal_matches  { "loanTypes": ["personal"], "country": "CA",
                               "credit": "good", "annualIncomeUsd": 70000, "amountUsd": 15000 }

Expect `preview: true`, a match list, and `missingForBetterMatch` naming answers
that would widen the search. Run it repeatedly — nothing accumulates.

    preview_prequal_matches  { "loanTypes": ["personal"], "country": "US",
                               "state": "NY", "credit": "fair", "annualIncomeUsd": 30000 }

Expect a `disqualifiers` entry explaining the state exclusion.

## 5. Consent gate

    submit_prequal  { "loanTypes": ["personal"], "country": "CA",
                      "consent": true, "disclosureAckId": "<any random uuid>" }

Expect `ack_invalid` — no submission without a real acknowledgement.

    submit_prequal  { ..., "consent": false, "disclosureAckId": "<uuid>" }

Expect a schema validation error: `consent` is a literal `true`.

    get_prequal_disclosure  { "loanTypes": ["personal"], "country": "CA" }

Returns the disclosure text and a `disclosureAckId`. Then:

    submit_prequal  { "loanTypes": ["business"], "country": "CA",
                      "consent": true, "disclosureAckId": "<that id>" }

Expect `ack_scope_mismatch` — consent given for a personal loan does not carry
over to a business loan.

## 6. Successful submission and single use

    get_prequal_disclosure  { "loanTypes": ["personal"], "country": "CA" }
    submit_prequal  { "loanTypes": ["personal"], "country": "CA", "credit": "good",
                      "annualIncomeUsd": 70000, "consent": true, "disclosureAckId": "<id>" }

Expect `submitted: true` and a `leadId`. Immediately repeat the same call with
the same acknowledgement — expect `ack_invalid`. One consent, one submission.

    get_prequal_status  { "leadId": "<leadId>" }

## 7. US submission does not submit

    get_prequal_disclosure  { "loanTypes": ["auto_purchase"], "country": "US" }
    submit_prequal  { "loanTypes": ["auto_purchase"], "country": "US", "state": "TX",
                      "credit": "good", "amountUsd": 30000, "consent": true, "disclosureAckId": "<id>" }

Expect `submitted: false`, `completion: "handoff"`, and a `funnelUrl` carrying
`state=TX` and `amount=30000`.

## Running the same checks locally

    npm install && npm test

53 tests cover the guards, the consent gate, the routing rules and the tool
contracts.

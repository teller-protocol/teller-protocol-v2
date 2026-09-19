# Step 02 — Security, privacy and legal

## What the connector collects

Only what a lender needs to decide whether to quote, all of it volunteered by
the user in conversation:

- Product(s) wanted, amount, timeline
- Country, and US state or Canadian province
- Employment type, gross annual income, years at job, existing monthly debt
- Self-reported credit band (a band — never an exact score)
- Birth **year** only
- For secured products: estimated home value and mortgage balance, or vehicle
  value and model year
- For business loans: entity type, industry, revenue, months trading
- Contact details (name, email, phone) — only at the point of submission

## What the connector refuses, by construction

The lender schema has detail blocks carrying government identifiers and bank
credentials. **This connector will not accept them.** These field names are
declared in the tool schema and rejected with an explanatory error:

`ssn` · `birthDate` · `driverLicenseNumber` · `routingNumber` · `accountNumber` ·
`usShortTermDetail` · `usHelocDetail` · `caLenderDetail`

They are refused loudly rather than silently dropped, so the assistant is told
to stop asking instead of carrying an identifier in its context. A second guard
(`GuardedPrequalClient`) re-checks the assembled payload at any depth before
anything leaves the process. Both behaviours are covered by tests.

**US applications are never completed in chat.** `check_prequal_route` returns a
link to Teller's own secure form, pre-filled with the answers already given.
`submit_prequal` for a US borrower returns that link and explicitly does not
submit. This keeps identity and bank details on a page the borrower can see, on
a domain they can verify.

Small-dollar / short-term US lending is excluded from this connector entirely.

## Consent

The lender-side contract requires the integrating application to collect consent
before a lead is routed. Here the integrating application is an assistant, so:

1. `get_prequal_disclosure` returns the disclosure text **and the assistant is
   instructed to display it verbatim**. The model does not author it.
2. It returns a single-use acknowledgement id, scoped by a hash of the exact
   products and country it was shown for, expiring in 30 minutes.
3. `submit_prequal` requires `consent: true` (enforced at the schema level as a
   literal) **and** a live acknowledgement whose scope matches what is actually
   being submitted. Reusing an acknowledgement, using an expired one, or
   changing the products after consent all fail closed.

There is no code path that submits a lead without a fresh, explicit, scoped
acknowledgement.

## Reversibility

- A preview stores nothing and reaches no lender. It is free and repeatable.
- A submission is irreversible and the tool description says so in those words.
- The assistant is instructed never to submit off the back of a preview alone.

## Retention

**[CONFIRM with Teller]** — retention period for submitted leads, deletion
request process, and whether preview answers are logged at all (they should not
be).

## Regulatory position

**[CONFIRM with counsel before submitting]**

- Lead generator of record, and the entity named on the disclosure.
- State-level lead-generation / broker licensing, and any states to exclude.
- Whether the current disclosure text satisfies TCPA consent requirements for
  automated contact, and E-SIGN for electronic consent.
- Canadian equivalents (CASL for electronic contact, provincial rules).

The disclosure text in `src/disclosure.ts` is a drafting starting point written
to be reviewed, not to be shipped as-is. It carries a version string
(`DISCLOSURE_VERSION`) that is recorded with every submission so consent can be
tied to the exact wording shown.

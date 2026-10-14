# Phase 13 Live Connector Certification

This procedure creates an immutable production certification only after genuine provider or official-statement checks are complete.

## Phase 13 scope

Included certification profiles:

- `plaid_uk` — UK/Europe account-data route, including the dedicated Revolut UK read-only path.
- `snaptrade` — read-only brokerage aggregation.
- `verified_manual` — official statements/documents verified manually.

`ctrader` is explicitly excluded from Phase 13 and the operator command rejects it.

## Safety rules

- Never put OAuth tokens, refresh tokens, client secrets, API keys, passwords, cookies, authorization headers, or private keys in the evidence JSON.
- Evidence records observations, timestamps, identifiers, reconciliation values, and references to retained source documents.
- A production certification requires an administrator reviewer from the same family.
- The deterministic certification policy decides PASS/FAIL; the operator command cannot override it.
- A later failed or overdue certification fails the production gate closed.
- Do not fabricate a live PASS from sandbox/demo/fixture data.

## Evidence JSON

Create the evidence JSON outside the repository. The structure is:

```json
{
  "environment": "production",
  "provider_key": "plaid_uk",
  "institution_key": "ins_63",
  "observed_scope": "transactions",
  "checks": {
    "institution_identity": true
  },
  "evidence": {
    "institution_identity": "Reference to retained live verification evidence"
  },
  "notes": "Optional operator notes"
}
```

The file must contain every check and every evidence item required by the selected profile in
`WealthOs::Connectors::CertificationPolicy`.

For Revolut UK, use `provider_key=plaid_uk` and the actual Plaid institution identifier observed by the live connection. The dedicated route expects `ins_63`.

For a manually verified account, use `provider_key=verified_manual`, `observed_scope=manual`, and a stable institution/route key that matches the account's certification record.

## Run the certification

```sh
FAMILY_ID="<family-id>" \
REVIEWER_EMAIL="<admin-email>" \
ACCOUNT_ID="<canonical-account-id>" \
EVIDENCE_FILE="/secure/path/provider.production.json" \
CONFIRM_LIVE=YES \
bin/rails wealth_os:certify_connector
```

The command prints certification metadata, the evidence SHA-256 digest, and missing-check/missing-evidence names. It does not print evidence content.

A successful result requires both:

```text
status = passed
production_gate = production_certified
```

A failed result is retained as immutable certification evidence and prevents authoritative use until superseded by a later valid production certification.

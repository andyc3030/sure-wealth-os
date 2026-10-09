# Phase 13 Live Connector Certification

This procedure creates an immutable production certification only after real-provider checks are complete.

## Safety rules

- Never paste OAuth tokens, refresh tokens, client secrets, API keys, passwords, cookies, authorization headers or private keys into the evidence JSON.
- Evidence should record observations, timestamps, source identifiers, reconciliation values and references to retained source documents.
- A production certification requires an administrator reviewer from the same family.
- A failed or later-overdue certification fails the production gate closed.

## cTrader / IC Markets first certification

Copy `docs/wealth-os/certification-templates/ctrader_ic_markets.production.json` outside the repository and fill it using a genuine live IC Markets cTrader connection.

Every required check must be explicitly verified and changed to `true`, with non-empty evidence for the same key.

Run:

```sh
FAMILY_ID="<family-id>" \
REVIEWER_EMAIL="<admin-email>" \
ACCOUNT_ID="<optional-canonical-account-id>" \
EVIDENCE_FILE="/secure/path/ctrader_ic_markets.production.json" \
CONFIRM_LIVE=YES \
bin/rails wealth_os:certify_connector
```

The command prints only certification metadata, the evidence SHA-256 digest, and missing-check/missing-evidence names. It does not print evidence content.

A successful result requires both:

```text
status = passed
production_gate = production_certified
```

## Required cTrader evidence

The current deterministic policy requires:

- institution identity
- canonical account identity
- balance/equity
- open positions
- pending orders
- historical deals
- commissions/swaps
- cash flows
- SCOPE_VIEW / accounts-only permission
- refresh preserving read-only scope
- reconnect without duplication
- revocation
- reconciliation against the external source
- confirmation that no trading requests are available or submitted

The live result must be reconciled against the source platform/statement. Synthetic, demo or fixture evidence is not a production PASS.

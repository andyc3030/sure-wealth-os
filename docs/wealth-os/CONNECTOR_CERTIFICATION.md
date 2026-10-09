# Connector Production Certification

## Purpose

Phase 9 separates three concepts that must not be conflated:

1. **provider support** — public/current documentation says a route exists;
2. **code readiness** — Wealth OS implements the intended read-only route and regression controls;
3. **production certification** — the exact real institution/account connection has passed live acceptance and reconciliation.

Only the third state is a production PASS.

## Immutable certification record

A certification captures:

- family and optional canonical account;
- provider profile and institution key;
- sandbox/demo/production environment;
- expected and observed access scope/profile;
- deterministic check results;
- evidence for every required check;
- SHA-256 digest of canonical evidence;
- checked timestamp;
- bounded review-due timestamp;
- production reviewer identity;
- superseded certification linkage;
- PASS/FAIL derived from policy.

Rows are append-only. Re-testing creates a successor record.

## Non-bypassable PASS

The model re-runs the provider certification policy during validation.

A direct database/model caller cannot obtain PASS by setting `status = passed`.

The record must actually have:

- expected scope/profile;
- every required check equal to TRUE;
- nonblank evidence for every required check;
- route type matching the configured provider policy;
- review due within the policy interval;
- for production, an authorized family-admin reviewer.

## Profiles

### Plaid UK

Expected access profile: `transactions`.

Required evidence covers institution identity, balances, transactions, pending/posted handling, currency, stable IDs, consent expiry, revocation, reconnect deduplication, statement reconciliation and absence of payment initiation.

### SnapTrade

Expected access scope: `read`.

Required evidence covers accounts, balances, positions, activities, cost-basis handling, distributions/fees, corporate actions, reconnect, revocation, freshness and absence of trading access.

### cTrader

Expected OAuth scope: `accounts`.

Required evidence covers account/institution identity, balance/equity, positions, pending orders, deals, commissions/swaps, cash flows, SCOPE_VIEW, scope preservation after refresh, reconnect, revocation, reconciliation and absence of trading requests.

### Verified manual

Expected profile: `manual`.

Requires official document evidence, account identity, balance/currency, statement date, verification timestamp, reconciliation and confirmation that the source portal was not scraped.

## Review intervals

- Plaid UK: 90 days
- SnapTrade: 90 days
- cTrader: 90 days
- verified manual: 28 days

The latest failed or overdue production certification fails closed.

## Evidence hygiene

Evidence should contain references, observations, reconciliation numbers, timestamps and provider/source identifiers needed for audit.

Never place:

- OAuth access/refresh tokens;
- client secrets;
- API keys/secrets;
- passwords;
- authorization headers;
- private keys;
- cookies

inside certification evidence.

The model rejects secret-bearing key names, but operational procedures must also avoid putting secret values under misleading benign keys.

## What code cannot do

Automated tests can prove that Wealth OS requests read-only access and rejects write messages.

They cannot prove:

- that a real user's bank/broker consent succeeded;
- that the institution returned all expected accounts;
- that balances/transactions/positions match the source institution;
- that revocation actually stopped provider access;
- that reconnect did not create a duplicate in a real provider session.

Those checks require the genuine provider connection and source records.

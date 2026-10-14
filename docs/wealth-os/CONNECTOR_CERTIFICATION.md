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

## Supersession and reviewer validity

Certification chains are environment-specific. A sandbox/demo record cannot be superseded by a production record and vice versa.

Production approval fails closed if the approving reviewer is no longer present or is no longer an authorized administrator in the same family.

The latest production record controls approval. A later failed record revokes an earlier pass.

## Live sync gate

Production certification is an operational gate, not only documentation.

For cTrader:

- demo automated sync is allowed for development/integration testing;
- direct live read-only snapshot import may be used deliberately to gather certification evidence;
- normal live automated sync is rejected until every discovered live account has current production certification.

## Phase 13 authoritative-use gate

Production approval is required when a source contributes to an authoritative daily close. The gate runs after the existing financial and quality checks and before immutable snapshot capture. UI rendering, initial OAuth connection and evidence collection remain available before certification.

The dedicated `WealthOs::DailyClose::CertificationGate` discovers authoritative sources through included visible accounts, their persisted provider relationships, normalized entry/holding provenance, and the income and liability contributors consumed by the ledger and forecast. Unused raw candidates do not create requirements. Derived rows reuse their account/source result; they are not independently certified.

| Source | Profile | Persisted institution identity |
| --- | --- | --- |
| Plaid Europe/UK | `plaid_uk` | Same-family `PlaidItem.institution_id` (including Revolut's `ins_63`) |
| SnapTrade | `snaptrade` | The unique institution key in the account's production certification records |
| Verified manual | `verified_manual` | The unique institution key in the account's production certification records |
| cTrader | Excluded from Phase 13 | No gate result or certification blocker |

Display names and brokerage names are not converted into institution keys. Missing, conflicting, cross-family or unsupported source mappings fail closed with `certification_source_unresolved`. A family-level external/manual contributor must resolve to a canonical source account through its persisted provenance. An account-scoped certification does not authorize another account or family.

Internal income/configuration with no external/manual provenance creates no additional requirement. The existing `loan_schedule` calculation source likewise reuses any authoritative external account source without manufacturing a manual certification. Liability payments can inherit provenance from their booked entry. Historical external/manual provenance remains subject to certification even if the account's current connection differs.

Resolved sources use the existing `ProductionGate`, which rejects missing production certification, latest failed certification, missing or unauthorized reviewers, missing review dates and overdue reviews. Verified manual follows the existing manual certification policy and review interval. This gate grants no broader provider permissions and changes no reconciliation, source-authority, valuation, FX, income or forecast rules.

Successful payloads contain the same structured result under `certification` and `pipeline.certification`. Each result contains canonical account/source identity, provider key, institution key, certification ID, approval and reason. Results are deduplicated by source/account and sorted deterministically, with no execution timestamp. Approval is evaluated at close execution time; a certification that expires before a later attempt blocks that attempt.

A rejected source raises `CertificationGate::Rejected` before snapshot capture. The coordinator records structured support diagnostics and continues to the next family. Rejected attempts can be retried after certification is corrected. Existing snapshots remain immutable; a different certification state changes the digest and cannot silently replace a prior close.

Pending entries excluded by the existing accounting scope do not create history-only certification requirements; their source is still checked if an included income or liability contributor independently references it. cTrader exclusion is applied after checking contributor labels, raw-source labels and explicit provider relationships for contradictions. Conflicting non-cTrader provenance fails closed without requesting cTrader certification.

Account source identities follow their persisted supersession chains, including successors recorded against newer raw records. A single current account mapping is used; multiple current heads, missing account mappings, or conflicts with a raw record's explicit account remain unresolved. Effective mappings are cached by source entity for the close attempt.

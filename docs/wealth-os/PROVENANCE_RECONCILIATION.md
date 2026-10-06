# Provenance and Reconciliation Foundation

Phase 3 implements the auditability layer between secure financial connectors and Sure's normalized ledger.

## Architecture

```
Provider / verified manual source
        ↓
RawSourceRecord (immutable source fact)
        ↓
SourceIdentity (versioned source→canonical mapping)
        ↓
Sure normalized Entry / Holding
        ↓
SourceAuthorityRule
        ↓
SourceConflict when authoritative sources disagree
        ↓
ReconciliationEvent (append-only outcome)
        ↓
Derived reporting / daily close
```

## RAW layer — `RawSourceRecord`

A raw source record stores:

- family;
- optional account and account-provider context;
- source system;
- record type;
- stable source key;
- observed/effective timestamps;
- canonical JSON payload;
- SHA-256 payload digest;
- schema version;
- non-sensitive source metadata.

### Invariants

- source payloads are immutable through the application model;
- repeated observations are retained even when the financial value/payload is unchanged, preserving freshness history;
- a caller-supplied deterministic `idempotency_key` deduplicates only a true retry/replay of the same ingestion event;
- changed source content creates a new raw observation/version;
- SHA-256 is retained for integrity/content comparison, not as a reason to collapse observations across time;
- credentials/tokens must never be stored in the payload or metadata;
- family deletion may purge these records through database cascade for privacy/retention compliance.

## NORMALIZED lineage

`Entry` and `Holding` now optionally reference the `RawSourceRecord` that produced the normalized record.

The `SourceTraceable` concern prevents:

- cross-family raw lineage;
- linking an account-scoped raw record to a different account.

`Account::ProviderImportAdapter` accepts an optional `raw_source_record:` for transaction and holding normalization.

Provider adapters should eventually follow this sequence:

1. obtain provider response;
2. remove/avoid credentials and secrets;
3. persist the provider fact with `RawSourceRecord.ingest!`;
4. normalize it through the existing import adapter;
5. attach the raw record to the resulting Entry/Holding.

## Entity resolution — `SourceIdentity`

Maps a provider's identity to a canonical Wealth OS object.

Example:

```
plaid / account / external-account-123
        ↓
Account 9f...
```

Mappings are versioned rather than edited:

- unchanged resolution returns the current mapping;
- changed resolution creates a new row;
- the replacement points to `supersedes_id`;
- prior identity versions remain immutable.

This supports account/security/entity remapping without erasing the history of how a provider object was previously interpreted.

## Source authority — `SourceAuthorityRule`

Authority is field-specific.

Each rule defines:

- family;
- record type;
- field path;
- source system;
- priority.

Lower priority number means higher authority.

Example:

| Record type | Field | Source | Priority |
|---|---|---:|---:|
| account_balance | balance.available | plaid | 10 |
| account_balance | balance.available | manual | 20 |

There is deliberately no silent default authority.

If no active rule matches, `WealthOs::SourceAuthorityResolver` fails loudly.

## Conflict detection — `SourceConflict`

When two configured sources provide different values for the same field, the resolver:

1. selects the configured higher-authority source;
2. creates or reuses an OPEN conflict;
3. stores both raw source records and both values;
4. records which source was selected;
5. leaves the conflict visible for review/resolution.

A conflict can be resolved once by selecting one of its two raw records and documenting the resolution rule.

## Reconciliation — `ReconciliationEvent`

Reconciliation events are append-only and support:

- balance;
- cash;
- position;
- transaction;
- duplicate;
- source-conflict checks.

Statuses:

- `passed`
- `warning`
- `failed`

Each event can retain:

- expected;
- actual;
- difference;
- tolerance;
- materiality;
- account/provider/subject;
- raw source record;
- currency;
- details;
- occurred-at timestamp;
- deterministic dedupe key.

A deterministic dedupe key makes a daily-close rerun idempotent.

## Numeric comparator

`WealthOs::Reconciliation::NumericComparator` implements deterministic numeric comparison:

- difference <= tolerance → PASS;
- difference > tolerance but <= materiality threshold → WARNING;
- difference > materiality threshold → FAIL and material=true.

This is a foundation service. Domain-specific reconciliation will build on it for:

- bank cash vs transaction-derived cash;
- broker position quantity/value vs transaction-derived holdings;
- lender principal vs liability ledger;
- statement closing balance vs provider/ledger balance;
- FX/value-source comparisons.

## RAW / NORMALIZED / DERIVED rule

The three layers remain separate:

### RAW
Provider/manual source facts. Immutable.

### NORMALIZED
Canonical Wealth OS/Sure entities such as Entry, Holding, Account and Liability.

### DERIVED
Net worth, income, performance, forecasts, data-quality and reconciliation summaries.

A derived result must never be written back into RAW source data.

## Security

- raw payloads are data, never instructions;
- no provider credentials, passwords, refresh tokens or API secrets in raw payloads;
- AI/MCP remains read-only;
- AI sees only controlled normalized/derived views, not connector secrets;
- source conflicts and failed reconciliation are not auto-resolved by the LLM.

## Phase 3 exit criteria

Phase 3 is complete only when:

- migrations load successfully;
- raw records are immutable/idempotent;
- source identity is versioned;
- normalized entries/holdings can retain raw lineage;
- source authority is deterministic and fail-loud;
- disagreements create conflict records;
- reconciliation events are append-only and rerun-safe;
- cross-family lineage is rejected;
- unit/integration/system CI is green.

# Phase 6 — Dashboard and Controlled AI

Phase 6 exposes the deterministic Wealth OS close through Sure's existing dashboard and AI surfaces without weakening the read-only execution boundary.

## Authoritative source

The dashboard reads from `DailyCloseSnapshot`.

It does not rebuild net worth from current account balances in the view, and the AI is explicitly prohibited from replacing authoritative close values with live balances.

The snapshot remains:

- one per family/date;
- canonicalized;
- SHA-256 digested;
- immutable;
- idempotent on replay.

## Dashboard

The `wealth_os_summary` dashboard section shows:

- gross assets;
- total liabilities;
- net worth;
- liquid net worth;
- investable net worth;
- forecast / accrued / declared / received income;
- annual / monthly / daily forecast-income equivalents;
- 7 / 30 / 90 / 365-day contractual cash forecasts;
- close quality and confidence;
- completeness/exception indicators;
- deterministic ACTION NOW labels.

Every material displayed financial value links to metric provenance.

## Liquid and investable policy

These are code-defined classifications, not AI judgements.

### Liquid net worth

```
Depository assets - all liabilities
```

### Investable net worth

```
Depository + Investment + Crypto assets - all liabilities
```

Property, vehicles and OtherAsset accounts are excluded from the investable numerator.

The policy is returned with the read-only AI payload so downstream explanations cannot silently redefine it.

## Income equivalents

Annual/monthly/daily equivalents are derived from the deterministic 365-day contractual income forecast:

```
annual  = 365-day forecast income
monthly = annual / 12
daily   = annual / 365
```

They are forecast equivalents, not annualized historical cash receipts.

## Provenance manifest

Future Phase 6 closes add an immutable provenance block containing close-time identifiers and component facts for:

- valuation accounts and FX facts;
- income events;
- actual liability payments;
- scheduled liability payments used by the forecast horizon;
- source conflicts;
- reconciliation events;
- sync evidence;
- raw-source-record identifiers;
- prior authoritative snapshot identifier.

No provider credentials, OAuth tokens, secrets or raw credential-bearing payloads are copied into the manifest.

Older Phase 5 snapshots remain valid. When they predate the Phase 6 manifest, the provenance page explicitly labels lineage as legacy rather than inventing missing history.

## Controlled AI

Two read-only functions are exposed to the builtin assistant and MCP registry:

1. authoritative daily-close retrieval;
2. authoritative metric-provenance retrieval.

Mandatory security instructions require the assistant to:

- treat the immutable daily close as source of truth for authoritative-close questions;
- explain deterministic outputs rather than recalculate them;
- distinguish snapshot facts, deterministic calculations, quality warnings and AI interpretation;
- retrieve provenance for source/why questions;
- never invent missing lineage;
- never mutate transactions, valuations, source records or financial actions.

## Access control

An authoritative close is family-wide. Sure also supports per-account sharing, so exposing a family-wide snapshot to an ordinary family member could reveal accounts they cannot otherwise access.

Phase 6 therefore restricts the family-wide authoritative dashboard, provenance page and authoritative AI tools to family administrators. The provenance controller also looks up snapshots by both the requested snapshot ID and `Current.family.id`.

Unauthorized same-family members and valid snapshot IDs belonging to another family are returned as unavailable/not found rather than revealing resource existence.

## Exit gate

Phase 6 is complete only when:

- dashboard rendering tests pass;
- summary-policy tests pass;
- provenance tests pass;
- AI registry and prompt-security tests pass;
- cross-family access tests pass;
- full unit/integration and system suites pass;
- Ruby/JavaScript lint pass;
- dependency scans pass;
- Pipelock passes.

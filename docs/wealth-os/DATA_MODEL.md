# Wealth OS Phase 3 Data Model

## New tables

### raw_source_records

Immutable, canonicalized provider/manual source facts.

Key columns:

- `family_id`
- `account_id`
- `account_provider_id`
- `source_system`
- `record_type`
- `source_key`
- `observed_at`
- `effective_at`
- `payload`
- `payload_sha256`
- `schema_version`
- `metadata`

### source_identities

Versioned source-object → canonical-object mapping.

Key columns:

- source system/entity type/external id;
- canonical polymorphic object;
- confidence;
- evidence raw record;
- verified timestamp;
- superseded identity version.

### source_authority_rules

Family-specific, field-specific source precedence.

Key columns:

- record type;
- field path;
- source system;
- numeric priority;
- active flag.

### source_conflicts

Auditable disagreements between source records.

Key columns:

- source record A/B;
- conflicting field;
- values A/B;
- selected source record;
- resolution rule;
- financial impact/currency;
- detected/resolved timestamps.

### reconciliation_events

Append-only reconciliation outcomes.

Key columns:

- kind/status;
- expected/actual/difference JSON;
- material flag;
- tolerance;
- currency;
- deterministic dedupe key;
- account/provider/subject/raw source lineage;
- occurred-at timestamp.

## Existing tables extended

### entries

Adds nullable `raw_source_record_id`.

### holdings

Adds nullable `raw_source_record_id`.

These pointers provide direct normalized→raw lineage without replacing Sure's established operational schema.

## Future Phase 3/4 extensions

The same lineage pattern can later be attached to:

- liabilities;
- income events;
- valuations where a direct Entry lineage is insufficient;
- FX rates;
- market prices;
- corporate actions;
- daily snapshots.

No new field should bypass source authority/reconciliation merely because it is added later.


# Phase 4 additions

## income_events

Canonical income-event records with exactly one current state:

- forecast;
- accrued;
- declared;
- received.

Important columns:

- family/account/security/raw-source lineage;
- canonical key;
- state and income type;
- gross / withholding / fee amounts;
- actual cash received amount;
- native currency;
- expected/accrual/declaration/payable/received dates;
- confidence;
- source identifiers and metadata.

## income_event_transitions

Append-only audit history for every income-event creation/revision/state transition.

## liability_payments

Immutable debt-payment decomposition:

- total;
- principal;
- interest;
- fees;
- insurance;
- actual/scheduled type;
- account/entry/raw-source lineage.

Database and model rules both require the payment components to equal the total.

## corporate_actions

Corporate-action source/accounting facts with audited lifecycle status transitions and immutable economic terms:

- affected security;
- optional account and successor security;
- effective date;
- split ratio or cash amount where relevant;
- action type;
- source lineage.

## corporate_action_transitions

Append-only audit history for corporate-action status progression.

Only validated/applied/reconciled split and reverse-split actions are consumed by holding reconstruction; unsupported action types remain non-mutating.

## Performance services

Performance remains deterministic service-layer calculation rather than mutable stored output at this phase:

- `Portfolio::Twr`;
- `Portfolio::ModifiedDietz`;
- `WealthOs::Performance::PortfolioReturns`;
- `WealthOs::Performance::FxAttribution`;
- `WealthOs::Performance::ReturnAttribution`;
- `WealthOs::Performance::NetWorthAttribution`.

Daily immutable performance snapshots are deferred to the authoritative daily-close phase.


# Phase 5 additions

## daily_close_snapshots

One immutable authoritative close per family and London close date.

Key columns:

- `family_id`;
- `close_date`;
- `cutoff_at` / `closed_at`;
- close timezone and reporting currency;
- PASS/WARNING quality status and deterministic confidence;
- gross assets / total liabilities / net worth in reporting currency;
- canonical JSON payload;
- SHA-256 payload digest;
- schema version.

The payload carries stage evidence, exact account valuations and FX lineage, income/liability accounting, performance bridge, contractual cash forecasts, quality evidence and deterministic ACTION NOW output.

A unique `family_id + close_date` index enforces one authoritative close. Replays must be equivalent at the canonical financial-content level or fail with an idempotency collision.

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

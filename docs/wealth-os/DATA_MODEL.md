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


## Research/advice amendment tables

### research_runs

Auditable research snapshots with family, as-of timestamp, methodology version and status.

### research_sources

Per-run/per-theme evaluated research sources with:

- source type and tier;
- publication/retrieval dates;
- six 0–5 quality scores;
- computed overall research-quality score;
- support/challenge/mixed/neutral thesis position;
- primary/institutional, academic and industry flags;
- promotional/commercial-conflict metadata;
- accepted/downgraded/rejected status;
- optional immutable raw-source link.

### research_claims

Evidence statements classified as:

- factual evidence;
- forecast;
- opinion;
- assumption;
- promotional material;
- investment recommendation.

Important claims can be tested for independent cross-check coverage.

### research_evidences

Claim→source links with support/challenge/context role, evidence summary, pinpoint reference and independence flag.

### research_theme_assessments

One assessment per theme/run containing:

- what the evidence says;
- genuine uncertainty;
- falsification tests;
- structural bottlenecks;
- highest-quality exposures;
- narrative-only beneficiaries;
- existing portfolio exposure;
- missing exposures.

### investment_recommendations

Advisory-only security conclusions with:

- increase / hold / reduce / exit / consider / avoid;
- core or aggressive-scenario sleeve;
- valuation and price context;
- entry/invalidation fields when evidenced;
- 3–5 year thesis;
- catalyst and risks;
- correlation/portfolio context;
- competitive-position, capital-intensity, cash-generation and balance-sheet analysis;
- current/proposed portfolio weights where applicable;
- current-price raw-source provenance.

### investment_recommendation_claims

Recommendation→claim evidence lineage.

No recommendation table or service is permitted to initiate execution.

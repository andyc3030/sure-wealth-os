# Wealth OS Adaptation Plan

## Phase 0 — Baseline and governance

- Pin upstream commit.
- Create protected development branches.
- Commit security baseline, connector matrix, source authority and audit.
- Do not connect the full real financial perimeter yet.

## Phase 1 — AI/MCP read-only hardening

- Replace shared mixed read/write AI registry with read-only registry.
- Restrict preview AI tools to reads.
- Dynamic MCP OAuth clients receive `read`.
- MCP accepts `read` only.
- Add tests proving all known AI write tools are absent/un-callable.
- Permit analysis/advice/recommendations while keeping them execution-isolated.
- Treat all external research content as untrusted data, not instructions.
- Prevent research content from changing permissions, connector scopes or system policy.

**Exit criterion:** CI passes and write tools cannot be reached through builtin AI or MCP; research/advisory output remains read-only and provenance-constrained.

## Phase 2 — Source inventory and connector verification

- Verify Santander UK coverage and field availability.
- Verify NatWest UK coverage and field availability.
- Verify Kent Reliance and classify unsupported savings accounts for verified-manual ingestion.
- Verify AJ Bell and Charles Schwab read-only brokerage routes.
- Verify IC Markets through cTrader Open API with OAuth `accounts` scope only.
- Add brokers, pensions, mortgages, property and other sources.
- Mark each DIRECT API / OPEN BANKING / AGGREGATOR / VERIFIED MANUAL / UNSUPPORTED.
- Maintain a separate institutional research-source inventory across all seven themes.
- Record source type, dates, independence group, conflicts, promotional status and dissenting/counter-thesis role.

## Phase 3 — Provenance and reconciliation foundation

Implemented foundation:

- immutable/idempotent `RawSourceRecord` source facts;
- normalized Entry/Holding → raw lineage;
- versioned `SourceIdentity` mappings for entity resolution;
- field-level `SourceAuthorityRule` precedence;
- auditable `SourceConflict` records;
- append-only, dedupe-safe `ReconciliationEvent` outcomes;
- deterministic numeric reconciliation comparator;
- cross-family/account lineage validation.

Phase 3 exit criteria:

- migrations and all tests pass;
- identical raw source content is idempotent;
- changed source facts create new immutable versions;
- missing authority rules fail loudly;
- conflicting sources create OPEN conflict records;
- reconciliation reruns do not duplicate events;
- normalized transaction/holding imports can retain raw lineage;
- AI/MCP remains read-only and cannot resolve conflicts or mutate raw facts.
- research sources/claims are provenance-linked and evidence-scored;
- each theme requires >=10 accepted sources, institutional/academic/industry mix, >=3 independent counter-thesis sources, and independent cross-checks for material factual claims;
- research assessments and recommendations are append-only;
- increase/consider recommendations require valuation, competitive-position, capital-intensity, cash-generation, balance-sheet and downside analysis plus sourced current price;
- Friday-NY 10W/50W/250W technical entry rule is deterministic and advisory only.

## Phase 4 — Accounting engines

- received/accrued/declared/forecast income;
- liability principal/interest/fees;
- corporate actions;
- TWR alongside MWR;
- capital/income/FX return;
- change-in-net-worth attribution.

## Phase 5 — Authoritative daily close

Configured defaults:

- timezone: Europe/London;
- cut-off: 23:59;
- reporting currency: GBP.

Daily orchestration:
sync → raw ingest → normalize → reconcile → value → income/liabilities → performance → forecast → quality → immutable snapshot → ACTION NOW report.

## Phase 6 — Dashboard and controlled AI

Reuse Sure UI and add:

- gross assets / total liabilities / net worth;
- liquid and investable net worth;
- received/accrued/declared/forecast income;
- annual/monthly/daily income equivalents;
- 7/30/90/365-day cash forecasts;
- data completeness and snapshot confidence;
- drill-down provenance for every material number.

AI explains deterministic results; it does not calculate or mutate source records.

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

**Exit criterion:** CI passes and write tools cannot be reached through builtin AI or MCP.

### Phase 1 research/advice amendment

- allow evidence-led analysis and advisory recommendations through read-only/public research inputs;
- treat all external research/document content as untrusted data;
- require provenance and explicit evidence classification;
- prohibit any recommendation → trade/payment/transfer execution path;
- require INSUFFICIENT EVIDENCE instead of unsupported completion.

## Phase 2 — Source inventory and connector verification

- Verify Santander UK coverage and field availability.
- Verify NatWest UK coverage and field availability.
- Verify Kent Reliance and classify unsupported savings accounts for verified-manual ingestion.
- Verify AJ Bell and Charles Schwab read-only brokerage routes.
- Verify IC Markets through cTrader Open API with OAuth `accounts` scope only.
- Add brokers, pensions, mortgages, property and other sources.
- Mark each DIRECT API / OPEN BANKING / AGGREGATOR / VERIFIED MANUAL / UNSUPPORTED.

### Phase 2 research-source amendment

Create a parallel research-source inventory, separate from account connectors:

- peer-reviewed/university;
- central-bank/government/multilateral/regulatory;
- primary-data institutions;
- institutional research with conflict disclosure;
- company filings and earnings calls;
- industry/standards/specialist research;
- reputable financial journalism;
- expert podcasts/interviews/opinion/promotional sources as lower-tier context.

For each of the seven research themes require at least 10 accepted sources, 2 primary/institutional, 1 academic, 1 industry source and 3 counter-thesis sources.

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

### Phase 3 research/advice amendment

Add reproducible research provenance:

- `ResearchRun`;
- scored `ResearchSource` records;
- evidence-classified `ResearchClaim` records;
- `ResearchEvidence` links with independent cross-checking;
- `ResearchThemeAssessment` investment translation;
- advisory-only `InvestmentRecommendation` records;
- recommendation→claim evidence lineage;
- tier-first source ranking and reproducible Top-25 source selection;
- theme-coverage and recommendation gates.

Important claims require at least two independent accepted publishers. Recommendations require counter-thesis/risk claims and cannot invent current prices.

## Phase 4 — Accounting engines + evidence-aware advisory integration

- received/accrued/declared/forecast income;
- liability principal/interest/fees;
- corporate actions;
- TWR alongside MWR;
- capital/income/FX return;
- change-in-net-worth attribution;
- expose deterministic accounting outputs to the research/advice layer;
- compare recommendations with current holdings, income, liabilities and concentration;
- keep recommendation generation separate from execution.

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

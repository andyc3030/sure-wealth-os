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

## Phase 2 — Source inventory and connector verification

- Verify Santander UK coverage and field availability.
- Verify NatWest UK coverage and field availability.
- Verify Kent Reliance and classify unsupported savings accounts for verified-manual ingestion.
- Verify AJ Bell and Charles Schwab read-only brokerage routes.
- Verify IC Markets through cTrader Open API with OAuth `accounts` scope only.
- Add brokers, pensions, mortgages, property and other sources.
- Mark each DIRECT API / OPEN BANKING / AGGREGATOR / VERIFIED MANUAL / UNSUPPORTED.

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

## Phase 4 — Accounting engines

Implemented deterministic foundation:

- audited four-state income ledger: forecast / accrued / declared / received;
- gross / withholding / fee / net income plus separately stored actual cash received;
- idempotent projection of booked Dividend/Interest transactions into RECEIVED income;
- immutable actual/scheduled liability-payment decomposition;
- principal vs interest/fees/insurance accounting;
- audited corporate-action lifecycle and split/reverse-split cost-preserving math;
- validated split-aware forward/reverse holding reconstruction without synthetic trades;
- exact chain-linked TWR engine;
- Modified Dietz fallback for periods without flow-boundary valuations;
- existing XIRR/MWR retained and reported separately from TWR;
- local-market vs FX attribution;
- capital / income / FX / fee / financing return attribution;
- deterministic change-in-net-worth bridge with visible residual.

Phase 4 exit criteria:

- database and model accounting constraints agree;
- income lifecycle cannot double-count current event state;
- backward income transitions are rejected and revisions are audited;
- debt payment components exactly equal total payment;
- scheduled liability decomposition is idempotent and reuses Sure's amortization schedule;
- £/$2,000 payment fixture with 1,250 principal + 700 interest + 50 fees reports 750 financing cost;
- split math preserves total cost;
- TWR and Modified Dietz golden fixtures pass;
- MWR continues to use the existing XIRR implementation;
- FX and return attribution components exactly reconcile to total change;
- net-worth bridge leaves material unexplained changes visible;
- AI/MCP remains read-only.

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

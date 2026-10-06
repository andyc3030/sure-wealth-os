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

- immutable raw source records;
- normalized source records;
- field-level source authority;
- conflict records;
- duplicate/entity resolution;
- account/position/cash reconciliation.

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

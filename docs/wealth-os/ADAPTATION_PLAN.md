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

Implemented deterministic close:

- timezone: Europe/London;
- cut-off: 23:59 local time, DST-aware;
- reporting currency: GBP;
- 23:30 London pre-close family sync using Sure's existing provider pipeline;
- post-midnight retry-safe finalization of the prior London date;
- exact-date normalized balance requirement for every included visible account;
- normalized FX only, with a five-day prior-rate window and no silent 1:1 cross-currency fallback;
- income and liability close ledger;
- 7/30/90/365-day contractual cash forecast;
- deterministic net-worth performance bridge without fabricated TWR/MWR;
- quality gate over sync, source conflicts, reconciliation and FX staleness;
- one immutable SHA-256-digested snapshot per family/date;
- deterministic ACTION NOW operational exceptions.

Daily orchestration:

sync → raw ingest → normalize → reconcile → value → income/liabilities → performance → forecast → quality → immutable snapshot → ACTION NOW report.

Phase 5 exit criteria:

- London cut-off is DST-aware;
- incomplete syncs defer finalization;
- failed/stale syncs, material source conflicts and material reconciliation failures block the authoritative snapshot;
- missing exact-date balances fail loudly;
- missing cross-currency FX fails loudly rather than substituting 1;
- stale prior FX is explicit and lowers snapshot quality;
- forecasts preserve undated income as unknown rather than inventing dates;
- identical daily-close replay is idempotent;
- changed financial content for an already-closed date raises an idempotency collision;
- snapshots are immutable;
- performance does not infer TWR/MWR without valid flow boundaries;
- AI/MCP remains read-only.

## Phase 6 — Dashboard and controlled AI

Implemented on top of the authoritative Phase 5 close:

- authoritative-close widget inside Sure's existing customizable dashboard;
- gross assets / total liabilities / net worth;
- deterministic liquid and investable net-worth policies;
- received / accrued / declared / forecast income;
- annual / monthly / daily equivalents derived from the 365-day contractual income forecast;
- 7 / 30 / 90 / 365-day contractual cash forecasts;
- data-completeness indicators and snapshot confidence;
- immutable close-time provenance manifests for valuation, income, liabilities, reconciliation, conflicts and sync evidence;
- metric-level provenance drill-down scoped to the signed-in family;
- read-only AI tools for authoritative-close retrieval and metric provenance;
- mandatory prompt rules prohibiting AI from recomputing or overriding authoritative snapshot values with live data.

Phase 6 exit criteria:

- every displayed material financial metric links to deterministic provenance;
- liquid/investable classifications are code-defined and exposed to the user;
- snapshot values are read from the immutable Phase 5 close rather than recalculated in the view or by AI;
- provenance contains identifiers and deterministic component facts, never provider credentials or raw secrets;
- AI can explain authoritative metrics but cannot mutate source records or execute financial actions;
- AI must not silently replace authoritative close values with live balances;
- cross-family snapshot/provenance access is rejected;
- unit/integration, system, lint, dependency and Pipelock security checks are green.

## Phase 7 — Research intelligence and advisory integration

Integrate the evidence-governed research foundation onto the current Phase 6 stack without changing the authoritative accounting close or read-only execution boundary.

Implemented scope:

- research-source provenance and transparent source-quality scoring;
- explicit fact / forecast / opinion / assumption / promotional / recommendation claim taxonomy;
- deterministic minimum-evidence, independent-cross-check and counter-thesis gates;
- theme assessments with uncertainty and falsification conditions;
- advisory investment recommendations with valuation, balance-sheet, downside, risk and portfolio-context requirements;
- sourced/timestamped price discipline;
- deterministic Friday New York weekly-entry gate using a configured 10-week-SMA tolerance;
- increase/consider validation re-runs the stored source/claim EvidenceGate rather than trusting assessment counters or flags;
- admin-only read AI/MCP access to stored research assessments and stored governed recommendations;
- research and recommendations remain advisory only and cannot trigger trades, transfers, payments, borrowing or financial-record mutation;
- accounting/daily-close facts remain authoritative for financial reporting and are not overwritten by research conclusions.

Phase 7 exit criteria:

- research foundation is integrated on top of the Phase 6 head;
- promotional sources cannot pass as accepted evidence;
- material factual claims require independent cross-checks;
- insufficient evidence blocks high-conviction increase/consider recommendations and cannot be bypassed by manually optimistic assessment fields;
- current-price recommendations require source, currency and timestamp;
- weekly technical gating fails closed when the near-10W tolerance is absent;
- research cannot mutate authoritative-close, source, transaction, valuation or execution state;
- unit/integration, system, lint, dependency and Pipelock security checks are green.

## Phase 8 — Income resilience and Income-at-Risk

Add a deterministic, auditable 365-day income-resilience layer on top of the canonical income ledger and authoritative daily close.

Implemented scope:

- 365-day dated baseline income from forecast / accrued / declared events;
- explicit state-retention policy: forecast 70%, accrued 90%, declared 100%;
- explicit confidence-retention policy: confirmed 100%, high 90%, estimated 75%, low 50%, unknown 0%;
- event-level stressed retained income and Income-at-Risk;
- aggregate stressed income, Income-at-Risk and sustainability ratio;
- stressed net cash after scheduled 365-day liability payments;
- source concentration, top-source share and HHI diagnostics;
- undated income excluded from the dated baseline and reported separately;
- close-date normalized FX, using the same fail-loud/staleness behavior as the authoritative close;
- immutable Phase 8 payload capture in new close schema version 2;
- dashboard and metric-level provenance;
- controlled AI explanation with an explicit prohibition on describing the model as statistical VaR, a confidence interval or a probability.

Definitions:

- baseline income = dated net economic income due after the close and within 365 days;
- stressed income = baseline event amount × state-retention factor × confidence-retention factor;
- Income-at-Risk = baseline income − stressed income;
- sustainability ratio = stressed income ÷ baseline income;
- stressed net cash = stressed income − scheduled 365-day liability payments.

Phase 8 exit criteria:

- the 365-day risk baseline reconciles to the same dated income population used by the contractual forecast;
- undated income is never silently included in or discarded from the model;
- every stress factor is code-defined and visible in provenance;
- zero baseline income produces no fabricated sustainability percentage;
- no statistical confidence/VaR claim is made;
- old snapshots remain immutable and report Phase 8 metrics as unavailable;
- controlled AI explains stored results but cannot invent alternative haircuts;
- unit/integration, system, lint, dependency and Pipelock security checks are green.

## Phase 9 — Production connector certification and live-source readiness

Turn the Phase 2 connector inventory into an auditable production-readiness framework and implement the dedicated cTrader read-only backend required for IC Markets.

Implemented scope:

- immutable connector-certification records with SHA-256 evidence digests;
- deterministic provider profiles for Plaid UK, SnapTrade, cTrader and verified-manual routes;
- every required production check must be TRUE and have recorded evidence;
- production certification requires an authorized family-administrator reviewer;
- certifications have bounded review horizons and supersede prior records append-only;
- latest failed or overdue production certification fails closed;
- certification evidence rejects credential-bearing keys;
- cTrader OAuth authorization hard-codes `scope=accounts`;
- token rotation clears observed permission until revalidated;
- cTrader account-list response must report `SCOPE_VIEW`; `SCOPE_TRADE` is rejected;
- cTrader request surface is allowlisted and all unknown/write messages fail closed;
- known order placement/cancel/amend/close payloads are explicitly blocked;
- live/demo cTrader environments are physically separated;
- TLS WebSocket JSON transport uses Spotware port 5036 with request correlation, heartbeat and timeouts;
- historical request rate is limited to Spotware's documented rate;
- cash-flow windows are capped at seven days;
- truncated deal/order history is split and refetched instead of silently accepted;
- account, position, order, deal and cash-flow provider facts land in immutable `RawSourceRecord` provenance;
- cTrader snapshots do not automatically mutate canonical Sure balances, holdings or trades;
- cTrader public connection UI remains disabled until real production certification exists.

Phase 9 exit criteria:

- a caller cannot self-assert PASS by bypassing the certification evaluator;
- a production PASS cannot exist without complete checks, complete evidence, expected permission and an authorized reviewer;
- an expired or later failed certification removes production approval;
- cTrader `trading` scope and execution requests are unreachable;
- missing live/demo account identity fails loudly;
- cTrader history requests use Unix milliseconds and do not silently truncate;
- credential/token values never enter raw provenance or certification evidence;
- raw cTrader provider facts retain source lineage without changing authoritative accounting state;
- code-level CI/security checks are green;
- real provider routes remain PENDING LIVE CERTIFICATION until genuine consent, revocation, reconnect and statement/broker reconciliation evidence is supplied.

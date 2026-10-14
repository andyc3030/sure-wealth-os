# Wealth OS completion audit

Audit baseline: `dc17038bdb76ebf6ed92a4104e87789cd7342d4e` (2026-10-14).

This audit replaces outdated completion assumptions, not financial policies. A
repository implementation and passing fixture-based CI do not establish a live
connection, production certification, deployment, or completeness of the user's
financial perimeter.

## Phase matrix

| Phase | Status | Evidence and remaining acceptance work |
| --- | --- | --- |
| 1: AI/MCP isolation | PARTIAL | Shared read-only registry, OAuth read scope, mutation rejection and account/admin scoping exist. Lock exact membership against accidental expansion. |
| 2: connector verification | BLOCKED EXTERNALLY | Routes and profiles exist. Genuine provider consent, revocation, reconnect and statement reconciliation are unavailable in the repository. |
| 3: provenance/reconciliation | PASS | RawSourceRecord, SourceIdentity, SourceAuthorityRule, SourceConflict and ReconciliationEvent implementations and regression tests are included in the green current full suite. |
| 4: accounting engines | PARTIAL | Income states, liability decomposition, splits, return and attribution engines exist and are tested. Explicit opening-anchor certification and historical/correction policy are missing. |
| 5: authoritative close | PARTIAL | DST-aware London cutoff, exact balances, FX and quality gates, immutable/idempotent snapshots and source certification are tested. Full performance integration and operating-state controls remain incomplete. |
| 6: dashboard/controlled AI | PARTIAL | Immutable snapshot summary, provenance and admin access exist. MTD/YTD/TTM income, complete performance and requested freshness/completeness measures are incomplete. |
| 7: research/advisory | PASS | EvidenceGate, WeeklyEntryGate, governed recommendations and read-only admin retrieval are implemented and covered by the green suite. Advisory output cannot execute. |
| 8: income resilience | PASS | Deterministic policy stress, undated-income handling, provenance and legacy unavailability are tested. No statistical VaR claim. |
| 9: connector certification framework | PASS | Immutable records, evidence digests, reviewer/family isolation, expiry and later-failure precedence are implemented and tested. Live evidence remains external. |
| 10–11: historical numbering | SUPERSEDED | No independent current phase contract was found. Requirements are tracked explicitly below rather than inferred from numbering. |
| 12: resilience | PASS | Current PR backup/restore fingerprint and previous-version rollback/recovery drills passed. This is CI drill evidence, not a production restore exercise. |
| 13: live production onboarding | BLOCKED EXTERNALLY | Revolut route, operator workflow, close certification and runtime publication are merged. Real credentials, consent, statements and deployment validation remain external. |
| Completion requirements | NOT STARTED | Opening/history contract, non-mutating corrections and explicit production operating-state model require dedicated reviewed implementation phases. |

PASS is scoped to the stated phase contract and current known evidence. New
findings reopen it. It does not imply overall production readiness.

## Verified publication and validation

Merged PRs: [15](https://github.com/andyc3030/sure-wealth-os/pull/15)
(Revolut), [16](https://github.com/andyc3030/sure-wealth-os/pull/16)
(integration/resilience), [17](https://github.com/andyc3030/sure-wealth-os/pull/17)
(runtime), [18](https://github.com/andyc3030/sure-wealth-os/pull/18)
(authoritative certification), [19](https://github.com/andyc3030/sure-wealth-os/pull/19)
(operator workflow). No open PR existed at audit start.

For PR 19 head `2795323fb3e093400e90f20b0e906ed3c155f6b3`:

- [Full CI](https://github.com/andyc3030/sure-wealth-os/actions/runs/38618875015): unit/integration, system, Ruby lint, JS lint, Ruby security and JS security passed.
- [Pipelock](https://github.com/andyc3030/sure-wealth-os/actions/runs/38618874946): passed.
- [Resilience](https://github.com/andyc3030/sure-wealth-os/actions/runs/38618874803): passed.

The [main runtime build](https://github.com/andyc3030/sure-wealth-os/actions/runs/38620764080)
published `ghcr.io/andyc3030/sure-wealth-os:phase13-dc17038bdb76ebf6ed92a4104e87789cd7342d4e`
and `phase13-latest`, with digest
`sha256:0548363b11d3b35613d05a1f157aa093459b94711375b9f589852a3942e85cc3`.
The moving tag may subsequently change; deploy the immutable tag/digest.

Local Ruby/Bundler are absent. Docker CLI exists but its Linux engine is
unreachable. No local Rails, lint/security Ruby or Docker execution is claimed.
CI is the authoritative executable validation until a runtime is available.

## Facts, assumptions, recommendations and blockers

Facts:

- DailyClose::PerformanceBuilder deliberately emits null TWR/MWR; the separate
  performance engines do not constitute authoritative dashboard integration.
- DailyClose::LedgerBuilder reports state totals and today's receipts, without
  captured MTD/YTD/TTM windows.
- Exact-date balance coverage measures included accounts only. It cannot prove
  all assets, liabilities or income sources were inventoried.
- Existing source certification is not a separately bound opening-balance
  approval. Missing opening/history policy must not be silently invented.
- Current AI tools deliberately evolved in Phases 1, 6 and 7; see the exact
  contract below. Do not silently replace it with nine differently named tools.
- No explicit Wealth OS suspension/operating-state or correction ledger was
  found. Immutable snapshot rejection alone is not a correction workflow.

Assumptions requiring confirmation before dependent architecture:

- Whether opening approval reuses connector certification or requires a separate
  immutable approval bound to each opening anchor/date/value/currency.
- Whether historical corrections require linked restatement snapshots or only
  prospective adjustments; existing family/date uniqueness forbids overwriting.

Recommendations:

1. Lock and document the actual AI allowlist; preserve all existing access gates.
2. Implement captured income windows and honest legacy unavailability.
3. Specify and implement opening/history and correction contracts before
   claiming the full accounting phase complete.
4. Implement audited suspension/degraded/readiness controls and observability.
5. Integrate performance only with certified opening values and explicit
   external flows/valuation boundaries; never infer missing returns.
6. Add freshness and perimeter coverage only with explicit evidence and policy;
   unknown must remain unknown, never 100% by default.

External blockers:

- Plaid UK production access and genuine Revolut consent/revocation/reconnect
  evidence, statement reconciliation and current same-family admin approval.
- Proven AJ Bell/Schwab read-only access and actual brokerage reconciliation.
- Official documents and review for verified-manual sources, including Revolut
  Trading. Do not scrape portals or store credentials in evidence.
- User-controlled runtime installation, encrypted secrets, persistent database,
  restore/rollback exercise, scheduler monitoring and incident validation.
- cTrader is excluded from Phase 13; its activation is not an acceptance blocker.

## Exact current AI contract

All callers: `get_transactions`, `get_recurring_transactions`, `get_accounts`,
`get_holdings`, `get_balance_sheet`, `get_income_statement`, `get_budget`,
`search_family_files`, `get_tags`, `get_categories`, `get_merchants`.

Additional same-family administrators: `get_authoritative_daily_close`,
`get_authoritative_metric_provenance`, `get_research_assessments`,
`get_investment_recommendations`.

Additional preview-enabled callers: `list_account_statements`,
`get_account_statement`, `get_statement_coverage`, `get_valuations`,
`get_insights`, `get_bills`, `get_bill_details`, `get_paycheck_plan`,
`get_bill_audit`.

Account-scoped reads retain their existing sharing policy. Family-wide close and
research reads retain their admin policy. MCP list and dispatch use the same
user-filtered registry. No write/execution tool may appear in any combination.

## Phase prompt: audit and exact AI contract

Objective: establish current evidence and prevent accidental expansion of the
existing reviewed model-visible read-only tool set.

Scope: this audit, exact membership tests across admin/member and preview states,
an MCP tools/list contract test, active-user enforcement in the static-token
fallback, and mandatory importmap security auditing in PR CI. Non-goals:
rename/add/remove tools, change OAuth or sharing, recalculate
financial metrics, enable cTrader, or claim live readiness. No migration or new
dependency is needed.

Requirements: assert explicit tool names independently of registry constants;
assert no duplicate names; cover both ordinary and admin callers with preview on
and off; verify external MCP publication matches the maximum approved set.
Preserve existing unknown/mutating-tool rejection coverage and all tenant gates.
Reject static-token requests after the configured user is deactivated, including
after a successful initialize. OAuth already has this active-user requirement.
The reusable CI workflow permits advisory JS auditing by default. Its PR caller
must explicitly require the audit so an ignored scan failure cannot satisfy the
project's security gate. Do not remove scans or suppress their findings.

Security/failure behavior: an added/removed/renamed visible tool must fail the
contract test and require deliberate review. Never derive expected values from
the implementation constants. Do not expose financial/provider evidence in the
audit. Existing dispatch remains fail-closed for unknown tools.

Validation: targeted Assistant and MCP tests, full unit/integration and system
suites, Ruby/JS lint, Ruby/JS security, Pipelock, backup/restore and
rollback/recovery. Record local unavailability; obtain actual green CI before
merge. Review the final diff and test independence. Confirm exact PR head and
clean working tree. Verify the new runtime image after the authentication fix is
merged; retain the prior verified image identity as rollback evidence.

Prompt review: the proposed nine-name surface contradicts the intentionally
evolved current implementation. Locking current membership preserves accepted
behavior without expanding privileges. The prompt separates live proof from CI,
preserves all prior controls and does not infer financial policy.

## Production verdict

**NOT PRODUCTION READY.** Repository gaps and live/operational evidence are still
missing. A green image build or operator command does not remove these gaps.

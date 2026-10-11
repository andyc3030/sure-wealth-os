# Wealth OS Phase 5 — Authoritative Daily Close

## Defaults

- timezone: `Europe/London`
- cut-off: `23:59` local time
- reporting currency: `GBP`

## Orchestration

The coordinator runs every 30 minutes to remain DST-aware. At approximately 23:30 London it requests the normal Sure family sync. After midnight it attempts to finalize the prior London date, deferring while any family/account/provider sync remains incomplete.

The close path is:

`sync settled → raw/normalized evidence → valuation → income/liabilities → performance bridge → 7/30/90/365 forecast → quality gate → immutable snapshot → ACTION NOW`.

## Accounting and valuation rules

- every included visible account needs an exact close-date normalized balance;
- missing exact-date balances block the close;
- GBP translation uses an exact normalized FX rate or the nearest prior normalized rate within five days;
- cross-currency FX never silently falls back to 1;
- stale weekend/holiday FX is explicit and lowers quality to WARNING;
- current income states and actual close-date cash received are stored separately;
- principal repayment is not financing expense;
- future income and scheduled liabilities are projected over 7/30/90/365 days;
- undated income stays undated and is counted explicitly.

## Performance

Phase 5 does not manufacture TWR or MWR from net-worth snapshots. With a prior authoritative close it stores a deterministic net-worth bridge for known received income, financing cost and insurance cost, while leaving the remainder visible as an unexplained residual.

## Quality gate

The close is blocked when there is:

- a material unresolved source conflict;
- a material failed reconciliation;
- a failed or stale sync.

Non-material source/reconciliation exceptions and stale FX produce WARNING.

Deterministic confidence:

- PASS = 1.00
- WARNING = 0.75
- FAIL = 0.25, but FAIL is blocked before snapshot creation

## Immutability

There is one authoritative snapshot per family/date. Identical replay returns the existing row. Different content for the same date raises an idempotency collision. Snapshot rows cannot be updated or individually destroyed. The canonical payload is SHA-256 digested.

## ACTION NOW

Rule-based operational output only:

- REVIEW — source conflicts
- RECONCILE — reconciliation exceptions
- RETRY SYNC — failed/stale sync
- WATCH — stale FX
- WATCH CASH — negative 30-day contractual cash forecast
- NO ACTION — no deterministic exception

AI/MCP remains read-only and cannot create or alter the authoritative close.

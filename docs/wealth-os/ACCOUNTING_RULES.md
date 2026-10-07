# Wealth OS Accounting Rules

These rules are invariants for deterministic financial calculations.

## Income

- Forecast, accrued, declared-unpaid and received are distinct concepts.
- One canonical income event occupies one current state at a time.
- Transition history is append-only.
- Never count the same economic income simultaneously in two current-state totals.
- Undeclared ordinary dividends are forecast, not accrued.
- Preserve gross income, withholding tax and fees separately.
- Preserve native currency; FX conversion must name its rate/source/time.

## Debt

- Principal repayment reduces cash and liability by equal amounts and is not an expense.
- Interest is financing expense.
- Debt fees are financing expense.
- Insurance is a separate non-principal cost.
- A liability payment must reconcile exactly to its components.
- Scheduled decomposition may use Sure's existing loan schedule; actual payments require source reconciliation.

## Corporate actions

- Do not infer a split from price movement alone.
- Corporate actions require a source fact.
- Split/reverse-split quantity and unit-cost adjustment must preserve total cost before cash-in-lieu effects.
- Return of capital is not automatically ordinary income; its accounting/tax character requires authoritative source data.
- No Phase 4 service mutates holdings automatically.

## Performance

- XIRR/MWR and TWR answer different questions and must be reported separately.
- TWR requires flow-boundary valuations; use Modified Dietz only as a labelled fallback.
- Contributions/withdrawals are external cash flows, not investment return.
- Income, capital, FX, fees and financing effects are separate attribution components.
- Missing FX is unknown, not parity.
- Unexplained performance/net-worth residuals remain visible reconciliation residuals.

## Deterministic engine vs AI

Critical arithmetic is performed by code/services, never by the LLM.

The AI may query and explain read-only outputs after deterministic calculation and provenance checks.

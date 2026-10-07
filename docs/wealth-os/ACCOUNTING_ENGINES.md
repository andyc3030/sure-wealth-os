# Phase 4 — Accounting Engines

This phase adds deterministic accounting primitives on top of Sure's existing transaction, holding, loan-amortization and XIRR infrastructure.

The AI layer remains read-only and does not perform these calculations.

## 1. Income accounting

### Four mutually exclusive current states

Each `IncomeEvent` is in exactly one current state:

1. `forecast` — expected but not yet economically earned/declared/received;
2. `accrued` — economically earned over an explicit accrual period but unpaid;
3. `declared` — formally declared/contractually payable but unpaid;
4. `received` — cash actually received.

An event has one canonical key per family and moves through an audited transition history.

### Transition rules

Allowed transitions:

```
forecast → forecast / accrued / declared / received
accrued  → accrued / declared / received
declared → declared / received
received → received
```

Same-state transitions are audited revisions, for example a forecast amount changing after new information arrives.

Backward transitions are rejected.

### Dividend nuance

Ordinary equity dividends do **not** accrue merely because time passes.

Before declaration they remain `forecast`.
Once officially declared they become `declared`.
On settlement they become `received`.

Interest/coupon/rent or other time-earned income may use `accrued` when an explicit accrual interval exists.

### Amounts

Each event keeps:

- gross amount;
- withholding tax;
- event-level fee;
- net amount = gross − withholding tax − fee;
- native currency;
- expected/accrual/declaration/payable/received dates;
- confidence;
- source/provenance.

No silent FX conversion occurs in `StateSummary`; currencies remain separate until an explicit FX policy is applied.

### Auditability

- the canonical event may only be revised through `transition_to!`;
- every creation/revision creates an append-only `IncomeEventTransition`;
- individual income events cannot be deleted through normal application code;
- family-level retention/privacy deletion can still cascade at database level.

## 2. Liability-payment accounting

`LiabilityPayment` persists the decomposition of an actual or scheduled debt payment:

```
Total payment
├── Principal
├── Interest
├── Fees
└── Insurance
```

Rules:

- principal is debt repayment, not financing expense;
- financing cost = interest + fees;
- insurance is kept separately;
- non-principal cost = interest + fees + insurance;
- total must exactly equal all components;
- all components are non-negative;
- payment rows are immutable.

Sure's existing `Loan::AmortizationSchedule` and `Loan#payment_breakdown` remain the source of amortization math. Phase 4 does not reimplement that formula.

Acceptance fixture:

```
Payment     2,000
Principal   1,250
Interest      700
Fees           50
Financing cost = 750
```

## 3. Corporate-action foundation

`CorporateAction` records source facts for:

- split;
- reverse split;
- merger;
- spin-off;
- rights;
- ticker change;
- cash dividend;
- special dividend;
- return of capital;
- fund reorganization.

At this phase corporate-action records are immutable source/accounting facts. No automatic holding mutation is enabled.

### Split math

`WealthOs::CorporateActions::SplitAdjustment` calculates:

```
new quantity  = old quantity × numerator / denominator
new unit cost = old unit cost × denominator / numerator
```

Therefore total cost is preserved.

This service is calculation-only. A later application/reconciliation workflow must verify the resulting provider holdings before changing canonical positions.

## 4. Investment performance

### Existing MWR retained

Sure's mature `Portfolio::Xirr` remains the money-weighted return engine.

MWR answers:

> What return did the investor experience given the timing and size of their cash flows?

### TWR added

`Portfolio::Twr` adds chain-linked time-weighted return.

TWR answers:

> What did the investments do independent of investor cash-flow timing?

Each TWR subperiod must be broken at an external cash-flow boundary.

Supported boundary conventions:

- `flow_timing: :begin` — flow enters before the subperiod return;
- `flow_timing: :end` — flow enters after the subperiod return;
- `flow_timing: :none` — no external flow.

The engine fails rather than fabricating a rate when the denominator is non-positive.

### Modified Dietz fallback

`Portfolio::ModifiedDietz` is available when exact flow-boundary valuations do not exist.

Formula:

```
R = (EMV − BMV − ΣCF)
    -----------------
    (BMV + Σ(w × CF))
```

where positive cash flows are contributions and each weight is the fraction of the period for which that flow was invested.

Do not label Modified Dietz as exact TWR.

### Side-by-side reporting

`WealthOs::Performance::PortfolioReturns` reports:

- TWR;
- existing XIRR/MWR;
- XIRR ambiguity flag.

The two measures must not be conflated.

## 5. Return attribution

`WealthOs::Performance::ReturnAttribution` separates:

- capital effect;
- income effect;
- FX effect;
- fee effect;
- financing-cost effect.

External contributions and withdrawals are removed before calculating investment return.

Signed accounting:

- income is positive;
- fees are negative;
- financing costs are negative;
- FX can be positive or negative;
- capital effect is the exact residual required to bridge total investment return.

No unexplained amount is silently discarded.

## 6. FX attribution

For a no-flow valuation segment:

```
Local market effect = (closing local − opening local) × opening FX
FX effect           = closing local × (closing FX − opening FX)
```

These sum exactly to the reporting-currency valuation change.

If an external cash flow occurs, split the measurement period at the cash-flow boundary before applying this decomposition.

## 7. Net-worth attribution

`WealthOs::Performance::NetWorthAttribution` bridges opening to closing net worth from explicit signed components and reports any residual.

Example debt payment:

```
cash used for principal       -1,250
liability principal reduction +1,250
financing cost                  -750
------------------------------------
net-worth change                -750
```

Principal therefore remains net-worth neutral while interest/fees reduce wealth.

The bridge exposes:

- actual change;
- explained change;
- residual;
- configured tolerance;
- `reconciled?`.

A non-zero material residual is a reconciliation issue, not an amount for the AI to explain away.

## 8. Explicit non-goals for Phase 4

This phase does **not** yet:

- automatically create income events from every provider;
- automatically apply corporate actions to holdings;
- perform tax filing/accounting;
- convert mixed-currency income without an explicit FX policy;
- replace provider/broker source reconciliation;
- expose financial write operations to AI/MCP;
- produce the final daily close/dashboard.

Those integrations belong to the daily-close/provider-normalization phases after the deterministic primitives are validated.

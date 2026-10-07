# Wealth OS Phase 4 — Accounting Engines

Phase 4 adds deterministic economic-accounting engines on top of Sure's existing transaction, investment, loan and balance models.

## 1. Income lifecycle

Wealth OS tracks four distinct concepts:

- **FORECAST** — expected but not yet legally/contractually due.
- **ACCRUED** — economically earned but not yet paid where accrual is appropriate.
- **DECLARED** — formally declared/known but unpaid.
- **RECEIVED** — cash has actually been received.

`IncomeEvent` is append-only and versioned. State progression creates a successor rather than rewriting history.

Typical dividend lifecycle:

```
FORECAST
   ↓
DECLARED
   ↓
RECEIVED
```

Interest/coupon income can legitimately use:

```
FORECAST
   ↓
ACCRUED
   ↓
RECEIVED
```

Ordinary undeclared equity dividends remain **forecast**, not accrued.

### No double counting

Only the current version of an economic event appears in lifecycle totals. When a dividend moves from Forecast → Declared → Received, the old states remain auditable history but are excluded from current totals.

### Received provider transactions

Booked investment transactions labelled:

- `Dividend`
- `Interest`

are projected into confirmed `RECEIVED` income events by `WealthOs::Income::ReceivedTransactionProjector`.

Pending transactions are ignored.

### Gross income versus cash received

An event can store:

- gross economic amount;
- tax withheld;
- fees;
- actual cash amount.

Therefore:

```
Gross income != necessarily cash received
```

This supports withholding-tax and fee reconciliation without redefining the underlying income event.

## 2. Liability payment accounting

Sure's existing `Loan::AmortizationSchedule` remains the deterministic source for scheduled principal/interest decomposition.

`LiabilityPayment` records:

- total payment;
- principal;
- interest;
- fees;
- insurance;
- payment state;
- source/provenance.

Economic rule:

```
Payment = Principal + Interest + Fees + Insurance

Principal:
  cash ↓
  liability ↓
  net-worth cost = 0

Financing cost:
  Interest + Fees

Insurance cost:
  Insurance
```

Canonical test:

```
Total payment      2,000
Principal          1,250
Interest             700
Fees                  50
-------------------------
Financing cost       750
Economic expense     750
Principal expense      0
```

This does **not** change Sure's household budgeting convention, where a loan payment may still be shown as a cash outflow. Wealth accounting and cash budgeting answer different questions.

## 3. Corporate actions

`CorporateAction` makes corporate events explicit rather than encoding them as fabricated trades.

Supported action records:

- stock split;
- reverse split;
- merger;
- spin-off;
- rights;
- special dividend;
- return of capital;
- symbol change;
- fund merger.

### Position handlers active in Phase 4

Only these are currently allowed to change reconstructed holdings automatically:

- **stock split**
- **reverse split**

For a split ratio `N:D`:

```
new quantity          = old quantity × N/D
new cost/unit         = old cost/unit ÷ N/D
total cost basis      = unchanged
cash flow             = zero
synthetic trade       = none
```

Both forward and reverse holding reconstruction apply confirmed split actions at the correct date, before same-day trades.

### Other corporate-action types

The other action types are first-class records for provenance/reconciliation, but they do **not** silently mutate positions in Phase 4.

Merger, spin-off, rights, return-of-capital and fund-merger handlers require explicit deterministic transformation rules before being enabled. Until then, they should create a review/reconciliation exception rather than guessed accounting.

## 4. Money-weighted return

Sure's existing `Portfolio::Xirr` remains the money-weighted return engine.

It answers:

> What return did the investor experience given the size and timing of external cash flows?

Do not label XIRR as TWR.

## 5. Time-weighted return

`Portfolio::Twr` chains valuation subperiod returns.

A caller must split the history at external cash-flow boundaries.

For a subperiod whose external flow occurs at the end:

```
growth factor = (ending value - external flow) / beginning value
```

Portfolio TWR:

```
TWR = product(all subperiod growth factors) - 1
```

Contributions and withdrawals therefore do not become investment performance.

The service refuses invalid subperiods such as a non-positive beginning value rather than fabricating a percentage.

## 6. Performance attribution

`WealthOs::Performance::Attribution` creates a deterministic change bridge:

```
Closing value
- Opening value
= Contributions
- Withdrawals
+ Income
- Fees
- Financing cost
- Insurance cost
+ FX effect
+ Capital return
+ Unexplained residual
```

The residual should be zero (within configured tolerance) for a completely explained period.

This separates:

- external contributions/withdrawals;
- income;
- fees;
- financing cost;
- insurance cost;
- FX effect;
- capital return.

It deliberately does not let contributions inflate investment return.

## 7. Relationship to Phase 3 provenance

Phase 4 records can retain `RawSourceRecord` lineage.

The intended flow is:

```
Immutable raw source
      ↓
normalized financial record
      ↓
IncomeEvent / LiabilityPayment / CorporateAction
      ↓
deterministic calculation
      ↓
reconciliation + report
```

AI remains downstream and read-only.

## 8. Phase 4 production gates

Phase 4 is ready only when:

- migration/schema load passes;
- income lifecycle transitions are tested and append-only;
- booked dividend/interest projection is idempotent;
- principal is excluded from financing expense;
- liability components reconcile to total cash payment;
- stock split/reverse-split quantity and basis math is tested;
- forward and reverse holding reconstruction both respect splits;
- no split fabricates a buy/sell or cash flow;
- TWR tests distinguish external flows from return;
- XIRR remains the separate MWR implementation;
- attribution bridge closes to zero on reference fixtures;
- unsupported corporate-action handlers remain non-mutating;
- unit/integration/system/lint/security CI is green.


## Additional accounting safety invariants

### Income lifecycle identity

A family may have only one lifecycle root for a given `event_key`.

Booked provider income keys are account-scoped as well as source/external-id scoped, because provider transaction IDs are not assumed to be globally unique across a family.

That root can then be superseded through the append-only state chain. This prevents two independent current chains from representing the same economic income event.

Accounting records also inherit Phase 3 raw-source lineage checks:

- raw evidence must belong to the same family;
- when a raw record is account-scoped, it must match the accounting record's account.

### Scheduled liability idempotency

Scheduled amortization decomposition is rerun-safe.

For a given loan/date/source:

- an identical scheduled decomposition returns the existing record;
- changed principal/interest/fee/insurance components fail loudly with `ScheduleConflict`;
- the database also enforces one scheduled row per loan/date/source.

Actual provider payments remain independently identifiable through provider `source_system + external_id`.

### Corporate-action confirmation

Corporate actions default to **pending**.

Only explicitly **confirmed** stock splits and reverse splits may alter reconstructed holdings.

Confirmed corporate actions are immutable through the application model. A confirmed split ratio cannot be edited in place after it has changed historical quantities/cost basis.

The database also prevents duplicate confirmed split events for the same family/security/type/effective date.

### Withholding tax

Performance attribution treats withholding tax as a separate reduction from gross income.

The bridge therefore distinguishes:

- gross income;
- withholding tax;
- account/platform fees;
- financing cost;
- insurance cost (separate from financing);
- FX effect;
- capital return.

This avoids forcing withholding tax into unexplained residual or mislabelling it as an investment-management fee.


### Performance-attribution residual

Capital return must be supplied independently by the deterministic valuation/performance engine. It is not solved as the balancing residual.

This preserves `unexplained_change` as a real reconciliation signal. A non-zero unexplained value indicates that market movement, income, FX, fees, financing, tax, flows, or another component is missing or inconsistent.

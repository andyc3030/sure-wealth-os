# Phase 8 — Income Resilience and Income-at-Risk

## Purpose

Add a conservative, deterministic income stress layer to Wealth OS without pretending to have a statistical loss distribution that the system does not possess.

The Phase 8 model is designed for cash-flow planning and income resilience. It is **not** market Value-at-Risk, earnings-at-risk at a statistical confidence level, or a probability forecast.

## Population

The baseline contains canonical income events that:

- are currently `forecast`, `accrued` or `declared`;
- have a payable / expected / accrual-end date strictly after the authoritative close date;
- fall within the next 365 days.

Received events are historical cash/economic income and are not part of future Income-at-Risk.

Undated future income is excluded from the dated baseline and reported separately by count and amount.

## Policy stress

Each dated event receives two deterministic retention factors.

### State retention

| State | Retention |
|---|---:|
| Declared | 100% |
| Accrued | 90% |
| Forecast | 70% |

### Confidence retention

| Confidence | Retention |
|---|---:|
| Confirmed | 100% |
| High | 90% |
| Estimated | 75% |
| Low | 50% |
| Unknown | 0% |

For each event:

`effective retention = state retention × confidence retention`

`stressed income = reporting-currency net income × effective retention`

`Income-at-Risk = reporting-currency net income − stressed income`

## Aggregate metrics

- **Baseline income** — dated 365-day income before stress.
- **Stressed income** — income retained after deterministic policy haircuts.
- **Income-at-Risk** — baseline minus stressed income.
- **Sustainability ratio** — stressed income divided by baseline income.
- **Stressed net cash** — stressed income minus scheduled 365-day liability payments.
- **Top-source share** — largest deterministic source group divided by baseline income.
- **Concentration HHI** — sum of squared source shares.

If baseline income is zero, the sustainability ratio and top-source share are unavailable rather than fabricated as zero.

## Source grouping

Concentration groups each income event by the first available deterministic identity:

1. security;
2. account;
3. source system;
4. income type.

The exact source key and event rows are captured in the immutable close for provenance.

## FX

Phase 8 uses the same normalized close-date FX resolver as Phase 5:

- exact close-date rate where available;
- permitted prior normalized rate within the existing stale-FX window;
- inverse normalized rate where valid;
- no silent 1:1 cross-currency fallback.

## Snapshot compatibility

Phase 8 authoritative closes use payload/schema version 2.

Older snapshots remain immutable. The dashboard and AI report Phase 8 metrics as unavailable for pre-Phase-8 snapshots instead of recalculating them from current data.

## Controlled AI

AI may explain:

- which events are stressed;
- the state/confidence policy factors;
- concentration;
- the difference between baseline and stressed income;
- stressed liability coverage.

AI must not:

- describe the result as statistical VaR;
- attach a probability/confidence interval to it;
- invent alternative haircuts while presenting them as authoritative;
- overwrite or recompute the immutable close.

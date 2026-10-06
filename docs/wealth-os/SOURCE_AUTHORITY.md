# Source Authority and Conflict Rules

Source precedence is **field-specific**, not global.

## Initial authority rules

| Field | Primary authority | Fallback |
|---|---|---|
| Bank cash balance | Direct institution / approved Open Banking feed | Official statement, then verified manual |
| Bank transaction | Direct institution / approved Open Banking feed | Official statement |
| Security quantity | Broker/custodian | Official statement, then transaction-derived |
| Security market price | Approved/authoritative market-data source | Exchange/broker mark |
| Cost basis | Broker tax-lot data | Transaction-derived, then official statement |
| Dividend declaration | Issuer/authoritative corporate-action feed | Broker |
| Mortgage/loan principal | Lender | Official statement, then verified manual |
| Property value | Verified valuation source | User-confirmed manual value |
| FX rate | Approved FX source | Provider FX |

## Conflict handling

Never silently choose between conflicting authoritative values.

For each material conflict retain:

- source A value and timestamp;
- source B value and timestamp;
- selected value;
- resolution rule;
- financial impact;
- resolution timestamp;
- reviewer/system decision.

## Data layers

1. **RAW** — immutable source facts.
2. **NORMALIZED** — canonical Sure/Wealth OS financial representation.
3. **DERIVED** — calculations such as net worth, income, performance, forecasts and data-quality scores.

Corrections create new versions or adjustment events. Raw source facts are never edited in place.

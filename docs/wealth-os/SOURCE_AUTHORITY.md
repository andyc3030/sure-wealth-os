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


## Implemented Phase 3 mechanics

The repository now implements these rules with:

- `RawSourceRecord` — immutable source evidence;
- `SourceAuthorityRule` — family/record/field/source priority;
- `WealthOs::SourceAuthorityResolver` — deterministic fail-loud selection;
- `SourceConflict` — auditable disagreement record.

Resolver behavior:

1. load active rules for the requested record type and field path;
2. ignore unconfigured source systems rather than silently trusting them;
3. order configured sources by ascending numeric priority;
4. choose the newest observation within the highest-authority source;
5. compare lower-authority configured candidates;
6. create/reuse an OPEN conflict when values disagree;
7. return the selected raw record/value and the rule that justified it.

There is no implicit source fallback when no rule exists.

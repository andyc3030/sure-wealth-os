# Connector Matrix

This file records planned routes only. A route is **not production-approved** until current provider coverage and required field availability are verified.

## Reporting defaults

| Setting | Value |
|---|---|
| Reporting timezone | Europe/London |
| Daily cut-off | 23:59 |
| Base currency | GBP |
| Manual valuation review interval | 28 days |

## Current source inventory

| Category | Provider | Account type | Country | Currency | Planned route | Status |
|---|---|---|---|---|---|---|
| Bank | Santander | Current | UK | GBP | Open Banking / Open Finance | Requires connector verification |
| Bank | NatWest | Current | UK | GBP | Open Banking / Open Finance | Requires connector verification |

## Verification checklist per institution

Confirm whether the chosen secure connector exposes:

- current and available balance;
- transaction history;
- account identifiers suitable for deduplication;
- interest income;
- fees;
- currency;
- consent expiry / reauthorization status.

For investment institutions additionally verify:

- positions and quantities;
- canonical security identifiers;
- cost basis;
- dividends/distributions;
- corporate actions;
- cash;
- margin/liabilities where applicable.

For lenders additionally verify:

- outstanding principal;
- interest rate;
- fixed/variable status;
- principal/interest/fee split;
- payment schedule;
- maturity/reset date.

## Rules

- Never invent connector availability.
- Never use browser credential scraping or MFA bypass.
- If no secure connector exists, use the verified-manual workflow.
- Do not classify a connector as adequate merely because it returns a balance.

# Connector Matrix

This file records planned routes and current verification state. A route is **not production-approved** until current provider coverage, required fields, credentials, and live consent flow have all been verified.

## Reporting defaults

| Setting | Value |
|---|---|
| Reporting timezone | Europe/London |
| Daily cut-off | 23:59 |
| Base currency | GBP |
| Manual valuation review interval | 28 days |

## Current source inventory

| Category | Provider | Account type | Country | Currency | Preferred route | Fallback route | Status |
|---|---|---|---|---|---|---|---|
| Bank | Santander | Current | UK | GBP | Plaid (Europe / UK) | Lunch Flow / verified manual | **Provider support verified; fork code enabled; live consent test pending** |
| Bank | NatWest | Current | UK | GBP | Plaid (Europe / UK) | Enable Banking | **Provider support verified; fork code enabled; live consent test pending** |

## UK connector verification — 2026-10-06

### Plaid

Plaid's current European coverage explorer lists both **NatWest** and **Santander** for the United Kingdom with Account Data support for personal/business accounts.

Evidence:

- https://plaid.com/docs/institutions/europe/
- https://plaid.com/docs/link/oauth/

Useful current institution IDs visible in Plaid documentation:

- Santander (UK) Personal and Business: `ins_62`
- NatWest: multiple UK institution records; Plaid's current docs show personal/business coverage and IDs vary by portal/product.

Sure baseline gap discovered during Phase 2:

- `Provider::Plaid#country_codes` for region `:eu` did not include `GB`.
- `Family#eu?` already treats UK families as eligible because only US/CA are excluded.
- Europe/UK Plaid links request **transactions only** in this Sure code path; payment initiation, investments and liabilities are not requested for this region.

Phase 2 patch:

- added `GB` to the Plaid Europe region;
- renamed the visible connector to **Plaid (Europe / UK)**;
- added regression coverage proving GB is present and that UK/Europe depository links request only `transactions`.

### Enable Banking

Enable Banking's February 2026 changelog explicitly added **NatWest (GB)** and documented further NatWest GB improvements.

Evidence:

- https://enablebanking.com/blog/2026/03/05/enable-banking-changelog-february-2026

Sure already has a native Enable Banking adapter that:

- discovers ASPSPs by ISO country code, including `GB`;
- requests balances and transactions;
- uses consent-based authorization;
- does not expose payment initiation through the Sure account-sync flow.

**NatWest fallback status:** verified provider + native Sure adapter; live consent still required.

**Santander UK via Enable Banking:** not promoted to verified status because current public evidence reviewed for this phase did not clearly identify Santander GB support. Do not assume it.

### Lunch Flow

Lunch Flow publicly advertises read-only Santander connectivity and has a native Sure adapter for balances, transactions and investment holdings where supported.

Evidence:

- https://www.lunchflow.app/coverage/santander
- https://www.lunchflow.app/coverage

Because the public Santander coverage page reviewed in this phase does not unambiguously identify the UK Santander portal, treat Lunch Flow as a **secondary candidate pending live geography confirmation**, not the primary verified UK route.

## Required live verification before production approval

For each UK bank connection:

1. configure production/sandbox provider credentials outside source control;
2. complete OAuth/Open Banking consent;
3. verify returned institution identity;
4. verify current balance;
5. verify transaction history;
6. verify pending/posted transaction behavior;
7. verify currency;
8. verify stable account identifiers for deduplication;
9. verify consent expiry / reauthorization behavior;
10. disconnect/revoke and confirm access stops;
11. reconnect and confirm account identity does not duplicate the existing Sure account;
12. reconcile provider balance and transactions against a recent official statement.

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
- Payment-initiation capability offered by a provider must not be requested or exposed by Wealth OS.

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
| Bank | Santander | Current | UK | GBP | Plaid (Europe / UK) | Lunch Flow / verified manual | **Phase 9 certification profile implemented; real production consent/reconciliation evidence still pending** |
| Bank | NatWest | Current | UK | GBP | Plaid (Europe / UK) | Enable Banking | **Phase 9 certification profile implemented; real production consent/reconciliation evidence still pending** |
| Bank | Revolut | Current / cash | UK | GBP / multi-currency | Plaid (Europe / UK) | Verified manual | **Phase 9 certification profile implemented; real production consent/reconciliation evidence still pending** |
| Savings | Kent Reliance | Savings / Cash ISA / fixed-term deposit | UK | GBP | Verified manual | Future secure connector if verified | **No Sure-compatible secure connector verified; online statements available for manual verification** |
| Broker | AJ Bell | Investment accounts | UK | GBP / multi-currency | SnapTrade read-only | Lunch Flow / verified manual | **Phase 9 certification profile implemented; hosted-credential security acceptance and real live reconciliation still pending** |
| Broker | Charles Schwab | Brokerage | US | USD / multi-currency | SnapTrade read-only | Verified manual | **Phase 9 certification profile implemented; broker approval and real live reconciliation still pending** |
| Broker | IC Markets Global | cTrader Raw / CFD trading account | Global | GBP / USD / account currency | cTrader Open API OAuth `accounts` scope | Verified manual | **Phase 9 read-only backend + certification gate implemented; demo and genuine live OAuth/reconciliation certification still required before public activation** |

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


## Brokerage connector verification — 2026-10-06

### SnapTrade + Sure

Sure's native SnapTrade client is already constrained to read-only connectivity:

- OAuth authorization defaults to `scope: "read"`;
- connection portal requests use `connectionType: "read"`;
- Sure imports accounts, balances, positions and activities;
- Sure does not expose SnapTrade trading endpoints in this connector path.

### AJ Bell

SnapTrade currently lists AJ Bell as **Read Only** and available once SnapTrade production access is approved.

Evidence:

- https://docs.snaptrade.com/docs/broker-access-guide
- https://snaptrade.com/brokerage-integrations/aj-bell-api

Important security distinction:

- AJ Bell does not expose a public developer API;
- SnapTrade's AJ Bell integration uses a hosted credential-based connection rather than OAuth;
- Wealth OS/Sure must never receive, log or store the AJ Bell username/password;
- this route is acceptable only as a supported third-party connector after explicit security acceptance and live verification.

Do not classify AJ Bell as equivalent to an OAuth/Open Banking connection.

### Charles Schwab

SnapTrade currently lists Schwab as **Read Only** after broker approval, with OAuth authentication. SnapTrade's public guide indicates approval is required before the connection becomes available.

Evidence:

- https://docs.snaptrade.com/docs/broker-access-guide
- https://snaptrade.com/brokerage-integrations/schwab-api

Use read-only access only. Do not provide separate Schwab trading API keys.

### Revolut UK

Plaid's current UK coverage lists Revolut for Account Data. It can use the same Plaid (Europe / UK) route added in this phase.

Evidence:

- https://plaid.com/docs/institutions/europe/


## Kent Reliance verification — 2026-10-06

Kent Reliance provides secure Online Services with real-time statements and downloadable account documents, but no Sure-compatible Open Banking/API route has been verified for this phase.

Evidence:

- https://www.kentreliance.co.uk/new-online-services-support
- https://www.kentreliance.co.uk/login/

Phase 2 classification:

- route: **Verified Manual**;
- capture balance, account type, contractual rate, maturity date where applicable, interest paid/accrued, statement date and verification timestamp;
- attach/source the value to a Kent Reliance statement or official account document;
- review at the configured manual-review interval;
- do not scrape Kent Reliance Online Services or store login credentials.

## IC Markets / cTrader verification — 2026-10-06

IC Markets cTrader accounts can use the official cTrader Open API. cTrader Open API uses OAuth 2.0 and exposes two relevant scopes:

- `accounts` — view-only account information/statistics; trading operations are impossible;
- `trading` — full trading authority.

Evidence:

- https://help.ctrader.com/open-api/account-authentication/
- https://help.ctrader.com/open-api/
- https://help.ctrader.com/open-api/api-application/

Wealth OS rule:

- request **only** `scope=accounts`;
- explicitly reject/never request `scope=trading`;
- build a dedicated Sure cTrader provider adapter before production use;
- ingest account identity, balance/equity, margin, positions, pending orders, historical deals/trades, commissions, swaps/financing and timestamps where the API exposes them;
- do not expose order placement or other trading operations anywhere in Wealth OS or AI/MCP.


## Phase 9 certification state

A route is no longer described as Production Approved merely because provider documentation says it exists.

Phase 9 records immutable certification results for:

- `plaid_uk`;
- `snaptrade`;
- `ctrader`;
- `verified_manual`.

A production PASS requires all profile checks, evidence for every check, the exact expected access scope/profile, an unexpired review horizon, and an authorized family-administrator reviewer.

Code/tests may prove that Wealth OS cannot request write authority. They **cannot** prove that a user's real institution connection returns the correct account, balance or transaction/position set. Those facts require a genuine provider session and reconciliation against the source institution.

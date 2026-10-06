# Brokerage Connector Verification

Date: 2026-10-06

## Wealth OS rule

Brokerage connectivity must be read-only. A provider supporting trading does **not** mean Wealth OS should request or expose trading authority.

## Sure SnapTrade implementation

The Sure connector already requests read-only access:

- OAuth authorize default: `scope: "read"`
- device authorization default: `scope: "read"`
- hosted brokerage connection: `connectionType: "read"`

The data path reads:

- accounts;
- balances;
- positions;
- activities;
- brokerage connection health.

It does not use trading endpoints for Wealth OS ingestion.

## AJ Bell

**Status:** Supported connector candidate — security acceptance and live test required.

Current SnapTrade evidence:

- AJ Bell is listed as **Read Only** and available after SnapTrade Production Access approval.
- SnapTrade's AJ Bell integration page states AJ Bell has no public developer API and that the hosted connection uses AJ Bell credentials.
- SnapTrade states the access is read-only.

Security consequence:

- Sure/Wealth OS must never collect AJ Bell credentials.
- Authentication must happen only inside SnapTrade's hosted connection flow.
- No credential value may enter Wealth OS logs, database, AI context or GitHub.
- If this credential-handling model is not accepted, classify AJ Bell as **Verified Manual** until a stronger connector becomes available.

Evidence:
- https://docs.snaptrade.com/docs/broker-access-guide
- https://snaptrade.com/brokerage-integrations/aj-bell-api

## Charles Schwab

**Status:** Verified connector route — approval/live test pending.

Current SnapTrade evidence:

- Schwab Read Only is generally available after broker approval.
- Authentication is OAuth.
- SnapTrade documents read-only portfolio connectivity separately from Schwab trading access.

Wealth OS rule:

- request/read only;
- do not supply Schwab trading API credentials;
- do not expose any SnapTrade trade capability.

Evidence:
- https://docs.snaptrade.com/docs/broker-access-guide
- https://snaptrade.com/brokerage-integrations/schwab-api
- https://support.snaptrade.com/Schwab-Read-Only-4a4feaa69a1c831b9dda0190145c6dd9?pvs=21

## Production acceptance tests for each brokerage

- institution identity is correct;
- all expected accounts appear once;
- account type/subtype is preserved where available;
- cash balance reconciles;
- positions and quantities reconcile;
- security identifiers/tickers are mapped deterministically;
- cost basis is compared to broker data and marked unknown if not supplied;
- dividends, interest, fees, buys, sells and transfers reconcile;
- corporate actions do not silently corrupt holdings;
- reconnect does not duplicate an account;
- revocation stops access;
- source timestamps and freshness are retained;
- no trading/order endpoint is reachable from Wealth OS AI/MCP.


## IC Markets Global / cTrader

**Status:** Direct read-only API route verified — dedicated Sure adapter and live test required.

IC Markets cTrader accounts are suitable for a direct connector through the official cTrader Open API.

cTrader Open API authentication is OAuth 2.0. The required Wealth OS permission is:

- `scope=accounts` — view-only account information/statistics; trading operations are impossible.

The following permission is forbidden for Wealth OS:

- `scope=trading` — grants trading authority.

Evidence:

- https://help.ctrader.com/open-api/account-authentication/
- https://help.ctrader.com/open-api/
- https://help.ctrader.com/open-api/api-application/

### Planned Sure adapter

Add a dedicated cTrader provider adapter that can read, where exposed by the API:

- cTrader account identity and account currency;
- balance and equity;
- free/used margin and margin statistics;
- current positions;
- pending orders as read-only exposure data;
- historical deals/trades;
- realised and unrealised P&L;
- commissions;
- swaps/financing;
- deposits/withdrawals or cash-flow equivalents where available;
- source timestamps and freshness.

### Security requirements

- OAuth authorization URL must hard-code/request `scope=accounts`;
- adapter must reject any token/authorization state that indicates trading scope;
- no trading/order-placement message may be implemented in the Wealth OS provider surface;
- AI/MCP receives normalized read-only data only, never cTrader OAuth secrets/tokens;
- demo account should be used for initial integration and reconciliation testing before live account approval.

### Production acceptance tests

- OAuth consent visibly requests accounts/view-only permission;
- returned account identity matches the intended IC Markets cTrader account;
- balance/equity reconcile to cTrader;
- positions and volumes reconcile;
- realised/unrealised P&L and fees reconcile within documented methodology;
- reconnect does not duplicate the account;
- revocation prevents further access;
- token refresh works without broadening scope;
- no trading operation is reachable through the adapter, service layer or AI/MCP.

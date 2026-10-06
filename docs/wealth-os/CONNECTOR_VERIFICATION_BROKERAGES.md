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

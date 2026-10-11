# cTrader / IC Markets Read-Only Connector

## Security objective

Ingest IC Markets cTrader account/exposure/history data while making order execution impossible from the Wealth OS connector surface.

## OAuth

Authorization always requests:

`scope=accounts`

Never:

`scope=trading`

After token acquisition or refresh, account discovery must return `SCOPE_VIEW`. A trade-scoped token is rejected before account import.

The trader model's account `accessRights` field is not used as a substitute for OAuth permission; the token's `permissionScope` is the application-access control.

## Network transport

- demo JSON WebSocket: `wss://demo.ctraderapi.com:5036`
- live JSON WebSocket: `wss://live.ctraderapi.com:5036`
- TLS certificate verification enabled;
- request/response correlation through `clientMsgId`;
- heartbeat on idle connection;
- bounded connection/response timeouts;
- demo/live account rows must explicitly match the selected environment.

## Positive request allowlist

Phase 9 allows only the messages needed to read:

- account access;
- assets/symbols;
- trader/account state;
- open positions and pending orders;
- historical deals/orders;
- cash-flow history;
- unrealized P&L.

Known execution requests for new orders, order cancellation/amendment, position SL/TP amendment and position closure are explicitly blocked. Every non-allowlisted payload is blocked as well.

## Historical completeness

- timestamps are Unix milliseconds;
- historical requests are rate-limited;
- cash-flow requests are split to at most seven days;
- `hasMore` deal/order responses are recursively split/refetched;
- history that remains truncated at a single timestamp fails loudly.

## Imported facts

Per account Wealth OS stores provider-side:

- identity/live-demo/broker metadata;
- deposit currency;
- balance;
- derived equity from balance + provider net unrealized P&L;
- used/free margin;
- symbol/asset catalog;
- open positions;
- pending orders;
- historical orders;
- historical deals;
- cash flows.

Each snapshot category also enters `RawSourceRecord` with source system `ctrader`.

OAuth tokens/client secrets are never copied into raw provenance.

## Canonical accounting boundary

Phase 9 deliberately does not turn these CFD provider snapshots into canonical Sure holdings, transactions or account balances automatically.

The provider facts must first pass live reconciliation and source-authority decisions. This avoids silently mapping CFD balance/equity/margin semantics onto ordinary brokerage accounting.

## Activation sequence

1. Register/approve the cTrader Open API application.
2. Configure client ID/secret only in runtime environment secrets.
3. Connect an IC Markets **demo** account with `accounts` scope.
4. Run import/reconciliation tests and verify SCOPE_VIEW.
5. Validate history, fees/swaps, cash flows and reconnect behavior.
6. Revoke and prove access stops.
7. Repeat against the intended live account.
8. Record a production certification with full evidence and admin reviewer.
9. Only then enable a public/live connector workflow.

## Automated live-sync boundary

The provider implementation separates certification evidence collection from normal production synchronization.

- Demo: normal sync is permitted.
- Live certification evidence: an explicit direct read-only snapshot import may be invoked.
- Live automated sync: blocked unless current production certification passes for every discovered account.

This prevents code readiness or possession of a token from becoming implicit production approval.

## Token invalidation

cTrader `ProtoOAAccountsTokenInvalidatedEvent` (payload type 2147) is treated as an authentication failure.

When received:

- pending reads fail;
- the transport remains poisoned for subsequent reads;
- the sync/import layer can mark the item as requiring credential/authorization update.

This covers server-side revocation, expiration and refresh invalidation behavior.

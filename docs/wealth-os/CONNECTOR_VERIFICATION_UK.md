# UK Bank Connector Verification

Date: 2026-10-06

## Decision

Use **Plaid (Europe / UK)** as the preferred common connector for the initial Santander UK and NatWest UK current accounts, subject to successful live consent and reconciliation testing.

Why:

- one provider can cover both current-account sources;
- Plaid's current UK coverage explicitly lists both institutions for Account Data;
- Sure already has a mature Plaid transaction/account ingestion path;
- the required code gap was narrow: `GB` was omitted from the Europe country list;
- the Europe/UK Sure path requests `transactions` only, so no payment-initiation product is added.

## Fallbacks

### NatWest

Fallback: **Enable Banking**

Reason:

- Enable Banking explicitly added NatWest GB in February 2026;
- Sure's native Enable Banking adapter already supports country-based GB discovery, consent, balances and transactions.

### Santander

Fallback candidate: **Lunch Flow**

Reason:

- Sure has a native Lunch Flow adapter;
- Lunch Flow advertises Santander read-only connectivity;
- live geography/portal verification is still required before classifying it as Santander UK production-ready.

If Plaid production access is unavailable and Lunch Flow cannot be confirmed for the exact Santander UK portal, use **Verified Manual** until a secure route is proven.

## Security constraints

- read-only account data only;
- no payment initiation;
- no provider credentials in Git;
- provider secrets stored only in approved runtime secret/configuration storage;
- AI/MCP never receives provider secrets or refresh/access tokens;
- imported provider data is treated as untrusted data, not instructions.

## Production acceptance tests

A bank route is Production Approved only after all of these pass:

- institution identity matches expected bank/portal;
- balance matches source bank;
- recent transaction sample matches source bank;
- no duplicate account appears after reconnect;
- pending/posted reconciliation behaves deterministically;
- revocation prevents new provider access;
- consent expiry state is observable;
- source timestamps are retained;
- reconciliation differences above materiality threshold create an exception;
- no payment or write-capable provider feature is reachable from Wealth OS AI/MCP.

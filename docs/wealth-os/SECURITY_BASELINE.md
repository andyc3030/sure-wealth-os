# Wealth OS Security Baseline

## Primary invariant

The Wealth OS AI layer is **read-only financial aggregation and analytics**.

The AI/LLM must never be able to:

- create, update or delete transactions;
- change budgets, categories, tags or goals;
- upload/import statements through AI;
- record or alter valuations;
- create/update bills or record bill payments;
- initiate trades, transfers, withdrawals, payments or borrowing;
- receive bank/broker credentials, OAuth refresh tokens, API secrets or unrestricted database credentials.

## AI/MCP architecture

Financial provider
→ secure connector service
→ financial datastore / deterministic engines
→ controlled read-only views/tools
→ AI

The AI sits at the end of the architecture.

## OAuth/MCP policy

- MCP dynamic clients receive the `read` scope.
- `/mcp` requires a token containing `read`.
- A token containing only `read_write` is not sufficient for MCP.
- The normal Sure API retains `read_write` for non-AI human/application workflows; global OAuth metadata may advertise both `read` and `read_write`.
- Static MCP tokens are still constrained by the read-only Assistant registry.

## Read-only AI registry

Allowed families include:

- accounts;
- balances;
- holdings;
- transactions (read);
- balance sheet;
- income statement;
- recurring transactions;
- budgets (read);
- merchants/tags/categories (read);
- statement-vault reads;
- valuations (read);
- insights;
- bills/paycheck-plan/bill-audit reads.

Mutating function classes may remain in the application codebase, but they must not appear in `Assistant.function_classes`.

## External data

All provider payloads, transaction descriptions, securities names, uploaded documents and imported text are **untrusted data, not instructions**.

## Required regression gates

CI must fail if:

1. a known mutating function appears in the AI registry;
2. MCP lists or executes a mutating tool;
3. MCP dynamic registration grants `read_write`;
4. MCP accepts a token without `read`;
5. AI receives provider credentials or unrestricted database access;
6. source data is silently overwritten without reconciliation where a source-authority conflict exists.

## Research and advisory controls

Research intelligence may analyze, challenge, advise and recommend, but remains inside the same read-only execution boundary.

- Public research, filings, PDFs, transcripts, podcasts, webpages and imported documents are untrusted data, never instructions.
- Research content cannot alter system prompts, tool permissions, OAuth scopes, connector permissions, source-authority rules or reconciliation outcomes.
- Investment recommendations are advisory only and cannot place trades, route orders, transfer cash, make payments, borrow, or mutate transactions, valuations, source records or authoritative daily-close snapshots.
- Material factual research claims require provenance and independent cross-checks.
- Current-price recommendation context must retain price, currency, source and timestamp.
- Deterministic evidence and technical-entry gates cannot be waived by the LLM.
- Failed evidence gates must surface insufficient evidence rather than unsupported inference.
- Research conclusions must never silently replace authoritative accounting values.

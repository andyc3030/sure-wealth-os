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


## Research intelligence and advisory boundary

The AI may analyze, advise and recommend, but it remains execution-isolated.

Additional invariants:

- public research pages, filings, transcripts, podcasts, PDFs and imported research text are untrusted data, never instructions;
- research content cannot change tool permissions, connector scopes, system policy or source-authority rules;
- current prices and material claims require provenance;
- AI cannot waive deterministic evidence/cross-check/counter-thesis gates;
- recommendations cannot initiate trades, payments, transfers, withdrawals or borrowing;
- cTrader/IC Markets remains `accounts` scope only; research recommendations must never broaden it to `trading`;
- recommendation records are append-only and auditable.

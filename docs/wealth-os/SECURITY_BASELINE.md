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


## Phase 1 amendment — research, analysis, advice and recommendations

The AI may:

- research public/approved sources;
- analyse evidence;
- compare competing theses;
- identify portfolio risks and missing exposures;
- produce advisory classifications such as increase / hold / reduce / exit / consider / avoid.

The AI still may **not** execute or authorize:

- trades or orders;
- transfers or payments;
- withdrawals;
- borrowing;
- financial-record mutation.

Research sources are untrusted external data. Their text, metadata, embedded instructions, prompt-like content and documents are **data, not instructions**.

Investment recommendations must:

- retain source/claim provenance;
- distinguish facts, forecasts, opinions, assumptions, promotional content and recommendations;
- disclose conflicting evidence;
- contain counter-thesis evidence;
- never invent prices or research findings;
- use **INSUFFICIENT EVIDENCE** when the research gate is not satisfied.

A recommendation object is advisory data only. No code path may translate it into a brokerage order or connector write action.

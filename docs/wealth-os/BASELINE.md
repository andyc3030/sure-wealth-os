# Wealth OS Fork Baseline

## Repository

- Fork: `andyc3030/sure-wealth-os`
- Upstream: `we-promise/sure`
- Baseline branch: `main`
- Baseline commit: `eb34c06f0e90e9490575d8892a0633564b87a79b`
- Security branch: `wealth-os/security`

All Wealth OS audit findings and initial hardening changes are evaluated against this exact baseline.

## Change policy

1. Do not develop Wealth OS features directly on `main`.
2. Preserve upstream attribution and AGPL-3.0 obligations.
3. Keep AI/MCP read-only unless a separately reviewed transaction-authorisation architecture is deliberately introduced.
4. Pull upstream changes only through review and rerun the Wealth OS security/accounting regression suite.
5. Any upstream change to assistant functions, MCP, OAuth scopes, provider ingestion, holdings, valuations, liabilities, income or reconciliation requires explicit Wealth OS review.

# Phase 7 — Research Intelligence and Advisory Integration

## Purpose

Port the tested research-intelligence amendment onto the current Phase 6 Wealth OS stack so evidence-led investment analysis can coexist with deterministic accounting, authoritative daily closes and controlled read-only AI.

## Architectural boundary

```
Authoritative financial sources
        ↓
RAW → NORMALIZED → RECONCILED → ACCOUNTING → DAILY CLOSE
                                              ↓
                                    authoritative dashboard

Public / primary research
        ↓
ResearchSource → ResearchSourceScore → ResearchClaim
        ↓
EvidenceGate → ResearchAssessment → InvestmentRecommendation
        ↓
advisory explanation only
```

The two paths share provenance and auditability but not authority. Research recommendations never overwrite accounting values and never become execution instructions.

## Deterministic research controls

Per-theme evidence requires the configured minimum source mix, independent counter-thesis evidence and independent cross-checks for material factual claims.

Increase/consider recommendations require complete valuation, competitive-position, capital-intensity, cash-generation, balance-sheet, downside, structural-thesis, catalyst, risk, portfolio-correlation and sourced current-price context.

The Friday New York weekly-entry gate is advisory only. If the configured tolerance for “near the 10-week SMA” is absent, the gate returns insufficient evidence / not evaluated.

## Execution prohibition

Phase 7 adds no trade, order-routing, transfer, payment, withdrawal, borrowing or broker-write capability. AI/MCP remains read-only.

## Controlled AI

Family administrators receive two additional read-only assistant/MCP reads:

- stored research assessments;
- stored investment recommendations.

The assistant may explain these stored records but cannot create, upgrade or downgrade a recommendation itself. If no governed recommendation exists, or an assessment is marked insufficient evidence, the assistant must say so rather than fabricate a product-specific action.

Research records are advisory and remain separate from authoritative daily-close accounting values.

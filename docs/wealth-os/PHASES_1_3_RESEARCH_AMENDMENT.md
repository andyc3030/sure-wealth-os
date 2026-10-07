# Phases 1–3 Research Intelligence Amendment

This amendment was introduced after the initial completion of Phases 1–3 and is implemented as a stacked change before Phase 4.

## Phase 1 amendment — security and AI boundary

Phase 1 now explicitly permits **analysis, advice and recommendations** while preserving read-only execution boundaries.

Additional requirements:

- research webpages, filings, PDFs, transcripts, podcasts, transaction descriptions and uploaded documents are untrusted data, never instructions;
- public-source content must not be able to alter tool permissions, connector scopes or system prompts;
- recommendations are advisory only;
- AI/MCP cannot trade, transfer, pay, borrow or mutate financial source data;
- current prices and research claims require provenance;
- the LLM cannot waive deterministic evidence gates.

## Phase 2 amendment — research-source inventory

Phase 2 now covers two distinct inventories:

### Financial data connectors

Banks, brokers, pensions, lenders and manual assets/liabilities.

### Research intelligence sources

Academic, institutional, regulatory, primary-data, filing, industry and journalism sources used for the seven thematic research programmes.

Research-source verification records:

- publisher;
- source type;
- publication date;
- URL;
- access timestamp;
- independence group;
- commercial conflict;
- promotional status;
- dissenting/counter-thesis status.

No source is ranked highly merely because it agrees with the current thesis.

## Phase 3 amendment — research provenance and evidence controls

Phase 3 now adds:

- `ResearchSource`;
- `ResearchSourceScore`;
- `ResearchClaim`;
- `ResearchAssessment`;
- `InvestmentRecommendation`;
- `WealthOs::Research::EvidenceGate`;
- `WealthOs::Research::WeeklyEntryGate`.

This extends provenance principles from financial facts to investment research.

### Minimum theme evidence gate

- >=10 accepted sources;
- >=2 primary/institutional;
- >=1 academic/university;
- >=1 high-quality industry;
- >=1 dissenting;
- >=3 independent counter-thesis sources;
- all material factual claims independently cross-checked.

### Recommendation evidence gate

Increase/consider requires full:

- valuation;
- competitive position;
- capital intensity;
- cash generation;
- balance sheet;
- downside;
- risks;
- sourced current price.

### Technical rule

Friday New York weekly:

- open below 50W SMA;
- close above 50W SMA;
- close above 250W SMA;
- close near 10W SMA using a configured tolerance.

This is advisory only.

## Phase 4 hand-off

Phase 4 should now consume this research foundation when implementing accounting/investment analytics, but must not merge research recommendations with deterministic accounting calculations.

Accounting remains accounting.

Research remains evidence-led advisory analysis.

Both share provenance and auditability.

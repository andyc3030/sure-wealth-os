# Analysis, Advice and Recommendation Policy

## Scope

Wealth OS may:

- analyze financial and public research data;
- compare theses and counter-theses;
- identify risks and bottlenecks;
- rank evidence quality;
- explain portfolio exposures;
- produce advisory increase/hold/reduce/exit/consider/avoid recommendations.

Wealth OS may not:

- place trades;
- route orders;
- transfer cash;
- modify broker/bank records through AI;
- broaden a read-only connector into trading scope;
- convert a recommendation into execution without an entirely separate, explicitly approved execution architecture.

## Deterministic / evidence-led boundary

The LLM may synthesize and explain.

Deterministic services must enforce:

- source minimums;
- source-type mix;
- source scoring;
- cross-check requirements;
- counter-thesis minimums;
- append-only assessment/recommendation versions;
- current-price timestamp requirement;
- technical-entry calculations.

The LLM cannot waive those gates.

## Recommendation states

- `increase`
- `hold`
- `reduce`
- `exit`
- `consider`
- `avoid`

## Allocation sleeve

Every investable recommendation is classified as:

- `core`
- `aggressive`
- `none`

## Price discipline

A recommendation using a current price must store:

- price;
- currency;
- source;
- timestamp.

No invented or stale current price may be presented as current.

## Research-to-recommendation flow

```
Public/primary research
        ↓
ResearchSource + ResearchSourceScore
        ↓
ResearchClaim
        ↓
EvidenceGate
        ↓
Theme ResearchAssessment
        ↓
Portfolio exposure / valuation / quality analysis
        ↓
WeeklyEntryGate where relevant
        ↓
InvestmentRecommendation
        ↓
Read-only AI explanation
```

A failed EvidenceGate blocks high-conviction recommendations and requires an **INSUFFICIENT EVIDENCE** label.

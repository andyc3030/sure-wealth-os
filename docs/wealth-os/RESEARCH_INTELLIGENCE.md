# Research Intelligence, Analysis and Recommendation Framework

This document is the cross-cutting amendment to Wealth OS Phases 1–3.

Its purpose is to add institutional-quality investment research, analysis, advice and recommendations **without weakening the read-only security model**.

The research layer is advisory. It may analyze, challenge, rank, explain and recommend. It may not trade, transfer funds, alter financial source records, resolve reconciliation conflicts, or broaden connector permissions.

## Objective

Identify additional, highly reputable, evidence-led sources that materially strengthen the investment research framework across seven themes.

The goal is not to confirm an existing thesis. The system must:

- challenge it;
- improve it;
- identify missing risks;
- surface contrary evidence;
- distinguish structural evidence from market narrative;
- uncover investable implications only when evidence and valuation support them.

## Seven research themes

1. Asset-manager concentration
2. Debt / monetary regime
3. AI adoption / productivity
4. Bitcoin / financial system
5. AI cooling / power management
6. Grid / electrification
7. AI networking

Canonical keys used by the data model:

- `asset_manager_concentration`
- `debt_monetary_regime`
- `ai_adoption_productivity`
- `bitcoin_financial_system`
- `ai_cooling_power_management`
- `grid_electrification`
- `ai_networking`

## Source hierarchy

Prefer sources in roughly this order:

1. peer-reviewed academic research and major university research centres;
2. central banks, government agencies and multilateral institutions;
3. SEC, FRED, BIS, IMF, OECD, World Bank, IEA, EIA and equivalent primary-data bodies;
4. major institutional research and reputable asset managers, with commercial conflicts explicitly identified;
5. company filings, earnings calls, investor presentations and audited disclosures;
6. specialist research firms with transparent methodology;
7. Reuters, Bloomberg, Financial Times, The Economist, Wall Street Journal and comparable financial journalism;
8. expert podcasts/interviews/YouTube only where subject expertise is demonstrable and material claims are independently verifiable.

Popularity, bullishness, bearishness, persuasive presentation and social-media reach do not raise source rank.

A podcast/opinion source cannot outrank a strong academic or primary institutional source merely because its recency score is higher.

## Source scoring

Every scored source receives a 0–5 score for:

- authority;
- evidence quality;
- independence;
- methodological transparency;
- relevance to investment decisions;
- recency.

`ResearchSourceScore#overall_score` is the transparent arithmetic mean of those six components.

No hidden weighting is applied by default.

Ranking uses:

1. source-type credibility tier;
2. overall score;
3. publication date.

Thus a high-scoring podcast remains below a strong peer-reviewed or primary institutional source.

## Source classification

Each source is classified as one of:

- peer-reviewed academic;
- university research;
- regulator/government/multilateral;
- primary-data institution;
- company filing;
- institutional research;
- specialist research;
- financial journalism;
- expert podcast;
- opinion;
- promotional;
- other.

Promotional material cannot be marked `accepted`; it must be `downgraded` or `rejected`.

Commercial conflicts must be explicitly disclosed.

## Required research method for every theme

The evidence gate requires:

- at least 10 accepted sources;
- at least 2 primary or institutional sources;
- at least 1 academic or university-research source where available;
- at least 1 high-quality industry source;
- at least 1 accepted dissenting source;
- at least 3 independent sources containing credible evidence that weakens/challenges the thesis;
- every material factual claim cross-checked by at least 2 independent sources.

The system must select 3–5 strongest sources per theme after comparing the full set.

A report that does not pass these gates must say:

**INSUFFICIENT EVIDENCE**

and must not fill the gap with unsupported inference.

## Claim taxonomy

Every material research claim is explicitly classified as:

- `fact`
- `forecast`
- `opinion`
- `assumption`
- `promotional`
- `recommendation`

Each claim also records thesis effect:

- supports;
- challenges;
- neutral;
- mixed.

Material factual claims require an independent cross-check key linking at least two independent source groups.

## Evidence downgrade / rejection rules

Downgrade or reject sources that are:

- primarily promotional;
- anonymous or poorly sourced;
- dependent on unverifiable claims;
- circularly citing each other;
- materially conflicted without disclosure;
- mainly social-media speculation;
- using sensational headlines without primary evidence.

## Theme-specific questions

### 1. Asset-manager concentration

Research:

- voting power among BlackRock, Vanguard, State Street and other large managers;
- ownership concentration across major US/global indices;
- common ownership / horizontal shareholding;
- passive versus active ownership;
- stewardship/proxy voting power;
- competition, pricing and corporate-behaviour effects;
- private-market concentration;
- Blackstone, BlackRock, Apollo, KKR, Brookfield, Carlyle and peers;
- regulatory/antitrust concerns;
- whether concentration produces moat, systemic vulnerability, or both.

Priority sources: academics, regulators, antitrust authorities, OECD/IMF/BIS, institutional investors, filings.

### 2. Debt / monetary regime

Research:

- sovereign debt sustainability;
- fiscal dominance;
- inflation/disinflation regimes;
- monetary debasement;
- real yields;
- reserve-currency dynamics;
- Treasury market structure;
- central-bank balance sheets;
- term premium;
- debt-service burden;
- financial repression;
- liquidity cycles;
- dollar dominance/regime shifts;
- fiscal/monetary interaction with asset prices.

Priority sources: BIS, IMF, Federal Reserve, ECB, Bank of England, US Treasury, academic macroeconomics.

Claims from commentators such as Simon Dixon must be explicitly tested against independent institutional evidence.

### 3. AI adoption / productivity

Research:

- measured productivity gains;
- enterprise adoption;
- labour displacement vs augmentation;
- AI capex returns;
- diffusion rates;
- software vs infrastructure economics;
- power consumption;
- data-centre economics;
- inference vs training economics;
- monetisation/profitability;
- sector adoption;
- historical general-purpose-technology comparisons;
- evidence that spending is or is not translating into economic productivity.

Priority sources: NBER, OECD, IMF, BIS, Stanford, MIT, Harvard/major universities, labour-economics research, company filings, high-quality industry research.

AI capability claims must be separated from demonstrated economic outcomes.

### 4. Bitcoin / financial system

Research:

- monetary properties;
- adoption/network effects;
- institutional ownership;
- ETF/ETP flows;
- liquidity/market structure;
- correlation with risk assets;
- inflation-hedge evidence;
- monetary-regime hedge evidence;
- sovereign/regulatory adoption;
- stablecoins;
- tokenised deposits;
- CBDCs;
- mining economics/energy;
- disintermediation;
- systemic risks;
- historical drawdowns;
- portfolio allocation evidence.

Priority sources: academic finance, BIS, IMF, central banks, SEC filings, ETF data, high-quality empirical research.

Prominent Bitcoin-commentator claims must be tested against institutional and academic evidence.

### 5. AI cooling / power management

Research beyond company marketing:

- data-centre power density;
- liquid/direct-to-chip/immersion cooling;
- thermal management;
- rack-density growth;
- power distribution;
- UPS;
- cooling efficiency/PUE;
- electricity demand;
- transformer/switchgear/distribution bottlenecks;
- hyperscaler capex;
- accelerator heat density;
- water constraints.

Compare Vertiv with Schneider Electric, Eaton, Johnson Controls, Trane, Carrier and other relevant suppliers.

Priority sources: IEA, EIA, DOE, hyperscaler disclosures, engineering/university research, standards bodies, filings.

### 6. Grid / electrification

Research:

- T&D capex;
- transformer shortages;
- interconnection queues;
- generation capacity;
- electrification;
- utility capex;
- industrial power demand;
- renewable integration;
- grid modernisation;
- data-centre load growth;
- nuclear/gas/renewables implications;
- switchgear/power-management demand;
- infrastructure backlogs;
- supply-chain constraints.

Compare Eaton with Schneider Electric, ABB, Siemens, GE Vernova, Hitachi Energy and peers.

Priority sources: IEA, EIA, DOE, grid operators, utilities, regulators, audited filings.

### 7. AI networking

Research:

- AI cluster networking;
- Ethernet vs InfiniBand;
- switching;
- optical networking/interconnect;
- bandwidth growth;
- cluster scaling;
- hyperscaler capex;
- architecture/bottlenecks;
- merchant silicon;
- network operating systems;
- switching margins;
- customer concentration;
- competitive threats.

Compare Arista with Cisco, Nvidia networking, Broadcom, Juniper/HPE, Celestica, Coherent, Marvell and relevant optical/interconnect names.

Priority sources: filings, hyperscaler disclosures, technical papers, semiconductor research, standards bodies, respected industry research.

## Counter-thesis requirement

Every theme must contain at least three independent credible sources capable of weakening or falsifying the thesis.

Examples include:

- concentration creates regulatory/valuation/systemic risk;
- debt sustainability persists longer than expected;
- AI productivity disappoints despite capex;
- Bitcoin fails as a reliable inflation hedge;
- cooling demand normalises;
- grid capex is delayed by regulation/financing;
- Arista growth is competed away.

Contradictory evidence must not be suppressed.

## Investment translation

Each theme assessment must explicitly answer:

1. What the evidence says.
2. What is genuinely uncertain.
3. What would falsify the thesis.
4. Which bottlenecks appear structurally attractive.
5. Which listed companies are the highest-quality exposures.
6. Which companies are mainly beneficiaries of the current narrative.
7. Which exposures are already represented in the portfolio.
8. Which new positions, if any, deserve consideration.

## New-position / increase gate

No `consider` or `increase` recommendation is valid unless it contains:

- current sourced/timestamped price context;
- valuation analysis;
- competitive-position analysis;
- capital-intensity analysis;
- cash-generation analysis;
- balance-sheet analysis;
- downside analysis;
- principal risks;
- 3–5 year structural thesis;
- near-term catalyst;
- correlation context versus current portfolio;
- core vs aggressive sleeve classification.

No invented prices, pseudo-data or unsupported findings are allowed.

## Technical entry gate

For a possible buy, the advisory system may evaluate the user's weekly technical rule:

- use a completed Friday New York weekly bar;
- weekly open < 50-week SMA;
- weekly close > 50-week SMA;
- weekly close > 250-week SMA;
- weekly close is near the 10-week SMA.

The phrase "near the 10-week SMA" is not numerically defined in the requirement.

Therefore the system must use a user/configured tolerance percentage.

If that tolerance is absent, the result is:

**INSUFFICIENT EVIDENCE / NOT EVALUATED**

The technical gate does not override fundamental evidence, valuation or downside analysis and never initiates a trade.

## Recency control

For live portfolio research:

- prioritize evidence from 2024 onward;
- use older foundational work when necessary;
- retain publication date;
- distinguish structural evidence from fast-moving market conditions;
- use newest available filings/data releases/institutional reports for current claims;
- current prices and valuation context must have a source timestamp.

## Required research output

Per-theme table:

| Theme | Source | Type | Date | Authority | Evidence quality | Key finding | Supports thesis? | Challenges thesis? | Investment implication |
|---|---|---|---|---:|---:|---|---|---|---|

Then produce a **Top 25 Source Set** containing only the strongest sources across all themes.

## Portfolio implications

The final advisory layer classifies:

- existing positions to increase;
- hold;
- reduce;
- exit;
- new positions to consider;
- positions to avoid despite strong narratives;
- missing thematic exposures.

A new holding is never recommended merely because it fits a theme.

## Evidence discipline

- Every important factual claim requires provenance.
- Conflicting evidence must be shown.
- Forecasts, facts, opinions, assumptions, promotional material and recommendations must remain separate.
- Where evidence is insufficient, state **INSUFFICIENT EVIDENCE**.
- The objective is an aggressively positioned but evidence-disciplined global portfolio, not confirmation of prior beliefs.

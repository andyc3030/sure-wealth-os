require "test_helper"

class WealthOs::Research::RecommendationGateTest < ActiveSupport::TestCase
  THEME = "grid_electrification"

  setup do
    @run = ResearchRun.create!(
      family: families(:dylan_family),
      as_of_at: Time.current,
      methodology_version: "1.0"
    )

    @sources = 10.times.map do |index|
      @run.research_sources.create!(
        theme: THEME,
        source_type: index.zero? ? "peer_reviewed" : (index == 1 ? "industry_research" : "government"),
        title: "Grid source #{index}",
        publisher: "Grid publisher #{index}",
        url: "https://example.com/grid-#{index}",
        publication_date: Date.current - index.days,
        retrieved_at: Time.current,
        source_tier: index.zero? ? 1 : 2,
        authority: 5,
        evidence_quality: 5,
        independence: 5,
        methodological_transparency: 5,
        relevance: 5,
        recency: 5,
        primary_or_institutional: index >= 2,
        academic: index.zero?,
        industry: index == 1,
        thesis_position: index < 3 ? "challenge" : "support"
      )
    end
  end

  test "reviewable recommendation requires both supporting and counter-thesis claims" do
    support = create_claim("support", "Grid capital expenditure remains elevated.")
    challenge = create_claim("challenge", "Permitting and financing can delay realised demand.")

    recommendation = create_recommendation
    InvestmentRecommendationClaim.create!(
      investment_recommendation: recommendation,
      research_claim: support,
      role: "supports"
    )
    InvestmentRecommendationClaim.create!(
      investment_recommendation: recommendation,
      research_claim: challenge,
      role: "challenges"
    )

    result = WealthOs::Research::RecommendationGate.call(recommendation)

    assert result.reviewable
    assert_empty result.errors
  end

  test "rejects recommendation with no counter-thesis claim" do
    support = create_claim("support", "Grid capital expenditure remains elevated.")
    recommendation = create_recommendation
    InvestmentRecommendationClaim.create!(
      investment_recommendation: recommendation,
      research_claim: support,
      role: "supports"
    )

    result = WealthOs::Research::RecommendationGate.call(recommendation)

    assert_not result.reviewable
    assert_includes result.errors, "requires at least two evidence-backed claims"
    assert_includes result.errors, "requires at least one counter-thesis/risk claim"
  end

  private

    def create_claim(stance, statement)
      claim = @run.research_claims.create!(
        theme: THEME,
        claim_kind: "factual_evidence",
        statement: statement,
        stance: stance,
        as_of_at: Time.current,
        status: "verified"
      )

      source = stance == "challenge" ? @sources[0] : @sources[4]
      ResearchEvidence.create!(
        research_claim: claim,
        research_source: source,
        role: stance == "challenge" ? "challenges" : "supports",
        evidence_summary: statement
      )
      claim
    end

    def create_recommendation
      @run.investment_recommendations.create!(
        theme: THEME,
        ticker: "TEST",
        company_name: "Test Grid Company",
        action: "consider",
        sleeve: "core",
        role_in_thesis: "Electrical distribution exposure",
        valuation_context: "Valuation must be compared with current earnings and cash flow.",
        structural_thesis: "Multi-year grid investment can support demand.",
        principal_risks: [ "capex delays", "multiple compression" ],
        correlation_context: "Assess overlap with existing industrial holdings.",
        portfolio_status: "missing",
        competitive_position: "Requires durable product/service differentiation.",
        capital_intensity: "Evaluate reinvestment requirements.",
        cash_generation_quality: "Require positive and resilient free cash flow.",
        balance_sheet_quality: "Require manageable leverage and liquidity.",
        as_of_at: Time.current
      )
    end
end

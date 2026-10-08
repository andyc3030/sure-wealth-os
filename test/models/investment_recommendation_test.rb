require "test_helper"

class InvestmentRecommendationTest < ActiveSupport::TestCase
  setup do
    @family = families(:dylan_family)
    create_passing_evidence(@family, "ai_networking")
    @assessment = ResearchAssessment.create!(
      family: @family,
      theme: "ai_networking",
      as_of_date: Date.current,
      methodology_version: "1.0",
      evidence_summary: "Evidence summary",
      uncertainty: "Key uncertainties",
      falsification_conditions: "Conditions that would falsify the thesis",
      source_count: 12,
      challenging_source_count: 3
    )
  end

  test "new capital recommendation requires full investment case and sourced current price" do
    recommendation = InvestmentRecommendation.new(
      family: @family,
      research_assessment: @assessment,
      action: "consider",
      company: "Example Networks"
    )

    assert_not recommendation.valid?
    assert recommendation.errors[:valuation_analysis].present?
    assert recommendation.errors[:balance_sheet_analysis].present?
    assert recommendation.errors[:reference_price].present?
    assert recommendation.errors[:near_term_catalyst].present?
    assert recommendation.errors[:correlation_context].present?
    assert recommendation.errors[:allocation_sleeve].present?
  end

  test "insufficient-evidence assessment blocks increase or consider" do
    insufficient = ResearchAssessment.create!(
      family: @family,
      theme: "ai_networking",
      as_of_date: Date.current + 1.day,
      methodology_version: "1.0",
      evidence_summary: "Evidence is incomplete",
      uncertainty: "Material uncertainty",
      falsification_conditions: "More evidence required",
      source_count: 4,
      challenging_source_count: 1,
      insufficient_evidence: true
    )

    recommendation = InvestmentRecommendation.new(
      family: @family,
      research_assessment: insufficient,
      action: "consider",
      ticker: "EXM",
      company: "Example Networks",
      reference_price: 100,
      price_currency: "USD",
      price_as_of: Time.current,
      price_source: "authoritative market data",
      structural_thesis: "Three-to-five-year thesis.",
      near_term_catalyst: "Capacity deployment.",
      principal_risks: [ "competition" ],
      correlation_context: "Compared with existing technology holdings.",
      allocation_sleeve: "aggressive",
      valuation_analysis: "Valuation analysis.",
      competitive_position_analysis: "Competitive analysis.",
      capital_intensity_analysis: "Capital-intensity analysis.",
      cash_generation_analysis: "Cash-generation analysis.",
      balance_sheet_analysis: "Balance-sheet analysis.",
      downside_analysis: "Downside analysis."
    )

    assert_not recommendation.valid?
    assert_includes recommendation.errors[:research_assessment],
      "has insufficient evidence for increase/consider recommendations"
  end

  test "manually optimistic assessment cannot bypass deterministic evidence gate" do
    optimistic = ResearchAssessment.create!(
      family: @family,
      theme: "bitcoin_financial_system",
      as_of_date: Date.current,
      methodology_version: "1.0",
      evidence_summary: "Claims sufficient evidence without underlying sources.",
      uncertainty: "Uncertainty",
      falsification_conditions: "Falsification conditions",
      source_count: 12,
      challenging_source_count: 3,
      insufficient_evidence: false
    )

    recommendation = InvestmentRecommendation.new(
      family: @family,
      research_assessment: optimistic,
      action: "consider",
      ticker: "EXM",
      company: "Example Networks",
      reference_price: 100,
      price_currency: "USD",
      price_as_of: Time.current,
      price_source: "authoritative market data",
      structural_thesis: "Three-to-five-year thesis.",
      near_term_catalyst: "Capacity deployment.",
      principal_risks: [ "competition" ],
      correlation_context: "Compared with existing holdings.",
      allocation_sleeve: "aggressive",
      valuation_analysis: "Valuation analysis.",
      competitive_position_analysis: "Competitive analysis.",
      capital_intensity_analysis: "Capital-intensity analysis.",
      cash_generation_analysis: "Cash-generation analysis.",
      balance_sheet_analysis: "Balance-sheet analysis.",
      downside_analysis: "Downside analysis."
    )

    assert_not recommendation.valid?
    assert recommendation.errors[:research_assessment].any? { |message|
      message.include?("does not pass deterministic evidence gate")
    }
  end

  test "complete new capital recommendation is valid and append-only" do
    recommendation = InvestmentRecommendation.create!(
      family: @family,
      research_assessment: @assessment,
      action: "consider",
      ticker: "EXM",
      company: "Example Networks",
      role_in_thesis: "AI networking exposure",
      reference_price: 100,
      price_currency: "USD",
      price_as_of: Time.current,
      price_source: "authoritative market data",
      entry_zone_low: 90,
      entry_zone_high: 100,
      invalidation_level: 80,
      structural_thesis: "Three-to-five-year thesis.",
      near_term_catalyst: "Capacity deployment.",
      principal_risks: [ "competition", "valuation" ],
      correlation_context: "Compared with existing technology holdings.",
      allocation_sleeve: "aggressive",
      valuation_analysis: "Valuation analysis.",
      competitive_position_analysis: "Competitive analysis.",
      capital_intensity_analysis: "Capital-intensity analysis.",
      cash_generation_analysis: "Cash-generation analysis.",
      balance_sheet_analysis: "Balance-sheet analysis.",
      downside_analysis: "Downside analysis.",
      evidence_quality_score: 4.5,
      technical_gate_status: "not_evaluated"
    )

    assert_not recommendation.update(action: "increase")
    assert_includes recommendation.errors[:base], "investment recommendations are append-only; create a new recommendation version"
  end
end

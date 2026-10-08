require "test_helper"

class InvestmentRecommendationTest < ActiveSupport::TestCase
  setup do
    @family = families(:dylan_family)
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

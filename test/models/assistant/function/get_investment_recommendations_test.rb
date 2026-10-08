# frozen_string_literal: true

require "test_helper"

class Assistant::Function::GetInvestmentRecommendationsTest < ActiveSupport::TestCase
  test "returns stored governed recommendations without execution capability" do
    user = users(:family_admin)
    assessment = create_assessment(user.family)
    recommendation = create_recommendation(user.family, assessment)

    result = Assistant::Function::GetInvestmentRecommendations.new(user).call("ticker" => "EXM")

    assert_equal true, result.fetch("advisory_only")
    assert_equal true, result.fetch("stored_recommendations_only")
    assert_equal false, result.fetch("execution_capability")

    row = result.fetch("recommendations").first
    assert_equal recommendation.id, row.fetch("id")
    assert_equal "consider", row.fetch("action")
    assert_equal "EXM", row.fetch("ticker")
    assert_equal "authoritative market data", row.fetch("price_source")
    assert_equal false, row.fetch("assessment_insufficient_evidence")
  end

  test "does not expose family-wide recommendations to a non-admin member" do
    result = Assistant::Function::GetInvestmentRecommendations.new(users(:family_member)).call

    assert_equal "research_intelligence_not_available", result.fetch("error")
  end

  test "does not return another family's recommendations" do
    user = users(:family_admin)
    other_family = Family.where.not(id: user.family_id).first
    skip "fixture requires a second family" unless other_family

    assessment = create_assessment(other_family)
    create_recommendation(other_family, assessment)

    result = Assistant::Function::GetInvestmentRecommendations.new(user).call("ticker" => "EXM")

    assert_equal [], result.fetch("recommendations")
  end

  private

    def create_assessment(family)
      ResearchAssessment.create!(
        family: family,
        theme: "ai_networking",
        as_of_date: Date.new(2026, 10, 8),
        methodology_version: "1.0",
        evidence_summary: "Evidence summary",
        uncertainty: "Key uncertainty",
        falsification_conditions: "What would falsify the thesis",
        source_count: 12,
        challenging_source_count: 3
      )
    end

    def create_recommendation(family, assessment)
      InvestmentRecommendation.create!(
        family: family,
        research_assessment: assessment,
        action: "consider",
        ticker: "EXM",
        company: "Example Networks",
        role_in_thesis: "AI networking exposure",
        reference_price: 100,
        price_currency: "USD",
        price_as_of: Time.zone.parse("2026-10-08 16:00:00"),
        price_source: "authoritative market data",
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
    end
end

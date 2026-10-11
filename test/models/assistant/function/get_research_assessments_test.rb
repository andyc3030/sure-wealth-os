# frozen_string_literal: true

require "test_helper"

class Assistant::Function::GetResearchAssessmentsTest < ActiveSupport::TestCase
  test "returns latest stored research assessment for an admin" do
    user = users(:family_admin)
    assessment = ResearchAssessment.create!(
      family: user.family,
      theme: "ai_networking",
      as_of_date: Date.new(2026, 10, 8),
      methodology_version: "1.0",
      evidence_summary: "Evidence summary",
      uncertainty: "Key uncertainty",
      falsification_conditions: "What would falsify the thesis",
      source_count: 12,
      challenging_source_count: 3
    )

    result = Assistant::Function::GetResearchAssessments.new(user).call("theme" => "ai_networking")

    assert_equal true, result.fetch("advisory_only")
    assert_equal false, result.fetch("execution_capability")
    assert_equal false, result.fetch("authoritative_accounting")
    assert_equal assessment.id, result.fetch("assessments").first.fetch("id")
    assert_equal false, result.fetch("assessments").first.fetch("insufficient_evidence")
  end

  test "does not expose family-wide research to a non-admin member" do
    result = Assistant::Function::GetResearchAssessments.new(users(:family_member)).call

    assert_equal "research_intelligence_not_available", result.fetch("error")
  end

  test "does not return another family's assessment" do
    user = users(:family_admin)
    other_family = Family.where.not(id: user.family_id).first
    skip "fixture requires a second family" unless other_family

    ResearchAssessment.create!(
      family: other_family,
      theme: "ai_networking",
      as_of_date: Date.new(2026, 10, 8),
      methodology_version: "1.0",
      evidence_summary: "Other family evidence",
      uncertainty: "Other family uncertainty",
      falsification_conditions: "Other family falsification",
      source_count: 12,
      challenging_source_count: 3
    )

    result = Assistant::Function::GetResearchAssessments.new(user).call("theme" => "ai_networking")

    assert_equal [], result.fetch("assessments")
  end
end

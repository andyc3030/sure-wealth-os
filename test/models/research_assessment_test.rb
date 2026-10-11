require "test_helper"

class ResearchAssessmentTest < ActiveSupport::TestCase
  test "assessment is append-only" do
    assessment = ResearchAssessment.create!(
      family: families(:dylan_family),
      theme: "debt_monetary_regime",
      as_of_date: Date.current,
      methodology_version: "1.0",
      evidence_summary: "Evidence summary",
      uncertainty: "Uncertainty",
      falsification_conditions: "Falsification conditions"
    )

    assert_not assessment.update(evidence_summary: "Rewritten")
    assert_includes assessment.errors[:base], "research assessments are append-only; create a new as-of version"
  end
end

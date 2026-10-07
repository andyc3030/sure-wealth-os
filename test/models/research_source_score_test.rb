require "test_helper"

class ResearchSourceScoreTest < ActiveSupport::TestCase
  test "calculates transparent unweighted overall score from six dimensions" do
    family = families(:dylan_family)
    source = ResearchSource.create!(
      family: family,
      theme: "ai_adoption_productivity",
      title: "Institutional AI study",
      publisher: "Example University",
      url: "https://example.edu/ai-study",
      source_type: "university_research",
      publication_date: Date.new(2026, 1, 1),
      accessed_at: Time.current,
      independence_group: "example-university"
    )

    score = ResearchSourceScore.create!(
      family: family,
      research_source: source,
      as_of_date: Date.current,
      authority_score: 5,
      evidence_quality_score: 4,
      independence_score: 5,
      methodology_transparency_score: 4,
      relevance_score: 5,
      recency_score: 5
    )

    assert_equal BigDecimal("4.67"), score.overall_score
  end

  test "promotional sources cannot be accepted" do
    source = ResearchSource.new(
      family: families(:dylan_family),
      theme: "ai_networking",
      title: "Vendor marketing page",
      publisher: "Vendor",
      url: "https://example.com/marketing",
      source_type: "promotional",
      promotional: true,
      status: "accepted",
      accessed_at: Time.current
    )

    assert_not source.valid?
    assert_includes source.errors[:status], "must be downgraded or rejected for promotional sources"
  end
end

require "test_helper"

class ResearchSourceTest < ActiveSupport::TestCase
  setup do
    @run = ResearchRun.create!(
      family: families(:dylan_family),
      as_of_at: Time.current,
      methodology_version: "1.0"
    )
  end

  test "calculates overall research quality as the mean of the six scores" do
    source = @run.research_sources.create!(
      theme: "debt_monetary_regime",
      source_type: "central_bank",
      title: "Central bank study",
      publisher: "Central Bank",
      url: "https://example.com/central-bank-study",
      retrieved_at: Time.current,
      source_tier: 1,
      authority: 5,
      evidence_quality: 5,
      independence: 5,
      methodological_transparency: 4,
      relevance: 5,
      recency: 4,
      primary_or_institutional: true
    )

    assert_equal BigDecimal("4.67"), source.overall_quality_score
  end

  test "tier-first ranking prevents opinion from outranking primary evidence" do
    institutional = @run.research_sources.create!(
      theme: "bitcoin_financial_system",
      source_type: "multilateral",
      title: "Institutional evidence",
      publisher: "Institution",
      url: "https://example.com/institutional",
      retrieved_at: Time.current,
      source_tier: 1,
      authority: 4,
      evidence_quality: 4,
      independence: 4,
      methodological_transparency: 4,
      relevance: 4,
      recency: 3,
      primary_or_institutional: true
    )

    @run.research_sources.create!(
      theme: "bitcoin_financial_system",
      source_type: "podcast_interview",
      title: "Recent persuasive interview",
      publisher: "Podcast",
      url: "https://example.com/podcast",
      retrieved_at: Time.current,
      publication_date: Date.current,
      source_tier: 4,
      authority: 5,
      evidence_quality: 5,
      independence: 5,
      methodological_transparency: 5,
      relevance: 5,
      recency: 5
    )

    assert_equal institutional, @run.research_sources.where(theme: "bitcoin_financial_system").ranked.first
  end
end

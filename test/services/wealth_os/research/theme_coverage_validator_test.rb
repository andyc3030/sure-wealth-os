require "test_helper"

class WealthOs::Research::ThemeCoverageValidatorTest < ActiveSupport::TestCase
  THEME = "ai_adoption_productivity"

  setup do
    @run = ResearchRun.create!(
      family: families(:dylan_family),
      as_of_at: Time.current,
      methodology_version: "1.0"
    )
  end

  test "passes only with institutional academic industry counter-thesis and claim cross-check coverage" do
    sources = 10.times.map do |index|
      create_source(
        index: index,
        source_type: index.zero? ? "peer_reviewed" : (index == 1 ? "industry_research" : "central_bank"),
        primary_or_institutional: index >= 2,
        academic: index.zero?,
        industry: index == 1,
        thesis_position: index < 3 ? "challenge" : "support"
      )
    end

    claim = @run.research_claims.create!(
      theme: THEME,
      claim_kind: "factual_evidence",
      statement: "Measured productivity impact is material in at least some tasks.",
      stance: "support",
      important: true,
      status: "verified",
      as_of_at: Time.current
    )

    ResearchEvidence.create!(
      research_claim: claim,
      research_source: sources[3],
      role: "supports",
      evidence_summary: "Independent evidence A"
    )
    ResearchEvidence.create!(
      research_claim: claim,
      research_source: sources[4],
      role: "supports",
      evidence_summary: "Independent evidence B"
    )

    result = WealthOs::Research::ThemeCoverageValidator.call(research_run: @run, theme: THEME)

    assert result.valid
    assert_empty result.errors
    assert_equal 10, result.counts[:sources]
    assert_equal 3, result.counts[:challenge]
    assert_equal 1, result.counts[:cross_checked_important_claims]
  end

  test "fails loudly when the counter-thesis requirement is missing" do
    10.times do |index|
      create_source(
        index: index,
        source_type: index.zero? ? "peer_reviewed" : (index == 1 ? "industry_research" : "central_bank"),
        primary_or_institutional: index >= 2,
        academic: index.zero?,
        industry: index == 1,
        thesis_position: "support"
      )
    end

    result = WealthOs::Research::ThemeCoverageValidator.call(research_run: @run, theme: THEME)

    assert_not result.valid
    assert_includes result.errors, "requires at least 3 credible counter-thesis sources"
  end

  private

    def create_source(index:, source_type:, primary_or_institutional:, academic:, industry:, thesis_position:)
      @run.research_sources.create!(
        theme: THEME,
        source_type: source_type,
        title: "Source #{index}",
        publisher: "Publisher #{index}",
        url: "https://example.com/source-#{index}",
        publication_date: Date.current - index.days,
        retrieved_at: Time.current,
        source_tier: index.zero? ? 1 : 2,
        authority: 5,
        evidence_quality: 5,
        independence: 5,
        methodological_transparency: 5,
        relevance: 5,
        recency: 5,
        primary_or_institutional: primary_or_institutional,
        academic: academic,
        industry: industry,
        thesis_position: thesis_position
      )
    end
end

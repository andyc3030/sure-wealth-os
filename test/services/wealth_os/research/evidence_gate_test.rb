require "test_helper"

class WealthOs::Research::EvidenceGateTest < ActiveSupport::TestCase
  test "passes only with institutional mix, counter-thesis and independent cross-checks" do
    family = families(:dylan_family)
    theme = "grid_electrification"

    specs = [
      [ "peer_reviewed_academic", "Academic A", false ],
      [ "regulator_government_multilateral", "IEA", false ],
      [ "primary_data_institution", "EIA", false ],
      [ "company_filing", "Eaton", false ],
      [ "institutional_research", "Institutional Research", false ],
      [ "specialist_research", "Grid Specialist", false ],
      [ "financial_journalism", "Reuters", true ],
      [ "financial_journalism", "Financial Times", true ],
      [ "university_research", "University B", true ],
      [ "expert_podcast", "Expert Interview", false ]
    ]

    sources = specs.each_with_index.map do |(source_type, publisher, dissenting), index|
      source = ResearchSource.create!(
        family: family,
        theme: theme,
        title: "Source #{index}",
        publisher: publisher,
        url: "https://example.com/source-#{index}",
        source_type: source_type,
        publication_date: Date.new(2025, 1, 1) + index.days,
        accessed_at: Time.current,
        independence_group: "independent-#{index}",
        dissenting: dissenting
      )
      ResearchSourceScore.create!(
        family: family,
        research_source: source,
        as_of_date: Date.current,
        authority_score: source_type == "expert_podcast" ? 5 : 4,
        evidence_quality_score: 4,
        independence_score: 4,
        methodology_transparency_score: 4,
        relevance_score: 5,
        recency_score: 5
      )
      source
    end

    ResearchClaim.create!(
      family: family,
      research_source: sources[1],
      theme: theme,
      claim_type: "fact",
      claim_summary: "Grid queues are materially larger than historical levels.",
      material: true,
      cross_check_key: "grid_queue_growth",
      thesis_effect: "supports"
    )
    ResearchClaim.create!(
      family: family,
      research_source: sources[2],
      theme: theme,
      claim_type: "fact",
      claim_summary: "Independent data also shows elevated interconnection queues.",
      material: true,
      cross_check_key: "grid_queue_growth",
      thesis_effect: "supports"
    )

    [ 6, 7, 8 ].each do |index|
      ResearchClaim.create!(
        family: family,
        research_source: sources[index],
        theme: theme,
        claim_type: "fact",
        claim_summary: "Counter-thesis evidence #{index}.",
        thesis_effect: "challenges"
      )
    end

    result = WealthOs::Research::EvidenceGate.call(
      theme: theme,
      sources: sources,
      claims: ResearchClaim.where(family: family, theme: theme).to_a
    )

    assert result.passed
    assert_empty result.deficiencies
    assert_equal 10, result.source_count
    assert_equal 3, result.challenging_source_count
    assert_operator result.top_sources.first.ranking_tier, :<, ResearchSource::RANKING_TIERS["expert_podcast"]
  end

  test "fails loudly when evidence is thin or material fact lacks cross-check" do
    family = families(:dylan_family)
    theme = "bitcoin_financial_system"
    source = ResearchSource.create!(
      family: family,
      theme: theme,
      title: "Single opinion",
      publisher: "Commentator",
      url: "https://example.com/opinion",
      source_type: "opinion",
      publication_date: Date.current,
      accessed_at: Time.current,
      independence_group: "commentator"
    )
    claim = ResearchClaim.create!(
      family: family,
      research_source: source,
      theme: theme,
      claim_type: "fact",
      claim_summary: "Material claim with no independent confirmation.",
      material: true,
      thesis_effect: "supports"
    )

    result = WealthOs::Research::EvidenceGate.call(theme: theme, sources: [ source ], claims: [ claim ])

    assert_not result.passed
    assert result.deficiencies.any? { |item| item.include?("fewer than 10") }
    assert result.deficiencies.any? { |item| item.include?("not cross-checked") }
  end
end

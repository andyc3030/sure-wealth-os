require "test_helper"

class WealthOs::Research::SourceSetSelectorTest < ActiveSupport::TestCase
  test "top 25 preserves at least three sources per theme and never more than five" do
    run = ResearchRun.create!(
      family: families(:dylan_family),
      as_of_at: Time.current,
      methodology_version: "1.0"
    )

    ResearchSource::THEMES.each_with_index do |theme, theme_index|
      5.times do |source_index|
        run.research_sources.create!(
          theme: theme,
          source_type: "central_bank",
          title: "#{theme} source #{source_index}",
          publisher: "#{theme} publisher #{source_index}",
          url: "https://example.com/#{theme_index}/#{source_index}",
          publication_date: Date.current - source_index.days,
          retrieved_at: Time.current,
          source_tier: 1,
          authority: 5,
          evidence_quality: 5,
          independence: 5,
          methodological_transparency: 5,
          relevance: 5,
          recency: 5,
          primary_or_institutional: true,
          thesis_position: source_index < 3 ? "challenge" : "support"
        )
      end
    end

    selected = WealthOs::Research::SourceSetSelector.new(research_run: run).top_25
    counts = selected.group_by(&:theme).transform_values(&:count)

    assert_equal 25, selected.length
    ResearchSource::THEMES.each do |theme|
      assert_operator counts.fetch(theme), :>=, 3
      assert_operator counts.fetch(theme), :<=, 5
    end
  end
end

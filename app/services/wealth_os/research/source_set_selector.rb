# frozen_string_literal: true

module WealthOs
  module Research
    class SourceSetSelector
      THEMES = ResearchSource::THEMES
      TOP_PER_THEME_MIN = 3
      TOP_PER_THEME_MAX = 5
      TOP_SET_SIZE = 25

      def initialize(research_run:)
        @research_run = research_run
      end

      def top_for_theme(theme, limit: TOP_PER_THEME_MAX)
        raise ArgumentError, "unknown theme" unless THEMES.include?(theme)
        raise ArgumentError, "limit must be between 3 and 5" unless limit.between?(TOP_PER_THEME_MIN, TOP_PER_THEME_MAX)

        ranked_sources(theme).limit(limit).to_a
      end

      def top_25
        selected = []
        counts = Hash.new(0)

        THEMES.each do |theme|
          ranked_sources(theme).limit(TOP_PER_THEME_MIN).each do |source|
            selected << source
            counts[theme] += 1
          end
        end

        remaining = @research_run.research_sources.accepted
          .where.not(id: selected.map(&:id))
          .to_a
          .sort_by { |source| ranking_key(source) }

        remaining.each do |source|
          break if selected.length >= TOP_SET_SIZE
          next if counts[source.theme] >= TOP_PER_THEME_MAX

          selected << source
          counts[source.theme] += 1
        end

        selected.first(TOP_SET_SIZE)
      end

      private

        def ranked_sources(theme)
          @research_run.research_sources.accepted.where(theme: theme).ranked
        end

        def ranking_key(source)
          [
            source.source_tier,
            -source.overall_quality_score.to_d,
            -(source.publication_date || Date.new(1900, 1, 1)).jd
          ]
        end
    end
  end
end

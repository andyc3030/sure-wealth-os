# frozen_string_literal: true

module WealthOs
  module Research
    class RunGate
      Result = Data.define(:ready, :errors, :top_25)

      def self.call(research_run)
        new(research_run).call
      end

      def initialize(research_run)
        @research_run = research_run
      end

      def call
        errors = []

        ResearchSource::THEMES.each do |theme|
          coverage = ThemeCoverageValidator.call(research_run: @research_run, theme: theme)
          coverage.errors.each { |error| errors << "#{theme}: #{error}" }

          assessment = @research_run.research_theme_assessments.find_by(theme: theme)
          if assessment.nil?
            errors << "#{theme}: missing theme assessment"
          elsif assessment.status == "insufficient_evidence"
            errors << "#{theme}: assessment is INSUFFICIENT EVIDENCE"
          end
        end

        top_25 = SourceSetSelector.new(research_run: @research_run).top_25
        errors << "Top 25 source set contains only #{top_25.length} sources" if top_25.length < SourceSetSelector::TOP_SET_SIZE

        @research_run.investment_recommendations.where.not(status: %w[rejected expired]).find_each do |recommendation|
          gate = RecommendationGate.call(recommendation)
          gate.errors.each { |error| errors << "#{recommendation.company_name}: #{error}" }
        end

        Result.new(errors.empty?, errors, top_25)
      end
    end
  end
end

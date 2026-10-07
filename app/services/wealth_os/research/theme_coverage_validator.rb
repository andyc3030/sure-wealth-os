# frozen_string_literal: true

module WealthOs
  module Research
    class ThemeCoverageValidator
      MIN_SOURCES = 10
      MIN_PRIMARY_OR_INSTITUTIONAL = 2
      MIN_ACADEMIC = 1
      MIN_INDUSTRY = 1
      MIN_CHALLENGE = 3

      Result = Data.define(:valid, :errors, :counts)

      def self.call(research_run:, theme:)
        new(research_run: research_run, theme: theme).call
      end

      def initialize(research_run:, theme:)
        @research_run = research_run
        @theme = theme
      end

      def call
        sources = @research_run.research_sources.accepted.where(theme: @theme)
        important_claims = @research_run.research_claims.where(theme: @theme, important: true)

        counts = {
          sources: sources.count,
          primary_or_institutional: sources.where(primary_or_institutional: true).count,
          academic: sources.where(academic: true).count,
          industry: sources.where(industry: true).count,
          challenge: sources.where(thesis_position: "challenge").count,
          important_claims: important_claims.count,
          cross_checked_important_claims: important_claims.count(&:independently_cross_checked?)
        }

        errors = []
        errors << "requires at least #{MIN_SOURCES} accepted sources" if counts[:sources] < MIN_SOURCES
        errors << "requires at least #{MIN_PRIMARY_OR_INSTITUTIONAL} primary/institutional sources" if counts[:primary_or_institutional] < MIN_PRIMARY_OR_INSTITUTIONAL
        errors << "requires at least #{MIN_ACADEMIC} academic/research-institution source" if counts[:academic] < MIN_ACADEMIC
        errors << "requires at least #{MIN_INDUSTRY} high-quality industry source" if counts[:industry] < MIN_INDUSTRY
        errors << "requires at least #{MIN_CHALLENGE} credible counter-thesis sources" if counts[:challenge] < MIN_CHALLENGE
        errors << "all important claims require at least two independent accepted publishers" if counts[:important_claims] != counts[:cross_checked_important_claims]

        Result.new(errors.empty?, errors, counts)
      end
    end
  end
end

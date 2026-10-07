# frozen_string_literal: true

module WealthOs
  module Research
    class RecommendationGate
      Result = Data.define(:reviewable, :errors)

      def self.call(recommendation)
        new(recommendation).call
      end

      def initialize(recommendation)
        @recommendation = recommendation
      end

      def call
        errors = []

        coverage = ThemeCoverageValidator.call(
          research_run: @recommendation.research_run,
          theme: @recommendation.theme
        )
        errors.concat(coverage.errors)

        claims = @recommendation.research_claims
        errors << "requires at least two evidence-backed claims" if claims.count < 2
        errors << "requires at least one counter-thesis/risk claim" unless claims.where(stance: "challenge").exists?
        errors << "linked important claims must be independently cross-checked" if claims.where(important: true).any? { |claim| !claim.independently_cross_checked? }

        if @recommendation.current_price.present?
          errors << "current price requires raw source provenance" if @recommendation.price_raw_source_record.nil?
          errors << "current price requires an as-of timestamp" if @recommendation.price_as_of_at.nil?
        end

        errors << "principal risks must not be empty" if @recommendation.principal_risks.blank?

        Result.new(errors.empty?, errors)
      end
    end
  end
end

# frozen_string_literal: true

class InvestmentRecommendationClaim < ApplicationRecord
  ROLES = %w[supports challenges risk catalyst valuation].freeze

  belongs_to :investment_recommendation
  belongs_to :research_claim

  validates :role, inclusion: { in: ROLES }
  validate :same_research_run_and_theme

  private

    def same_research_run_and_theme
      return if investment_recommendation.nil? || research_claim.nil?

      if investment_recommendation.research_run_id != research_claim.research_run_id
        errors.add(:base, "recommendation and claim must belong to the same research run")
      end

      if investment_recommendation.theme != research_claim.theme
        errors.add(:base, "recommendation and claim must belong to the same theme")
      end
    end
end

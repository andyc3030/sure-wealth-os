# frozen_string_literal: true

class ResearchEvidence < ApplicationRecord
  ROLES = %w[supports challenges context].freeze

  belongs_to :research_claim
  belongs_to :research_source

  validates :role, inclusion: { in: ROLES }
  validates :evidence_summary, presence: true
  validates :weight, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 1 }
  validate :same_research_run_and_theme

  private

    def same_research_run_and_theme
      return if research_claim.nil? || research_source.nil?

      if research_claim.research_run_id != research_source.research_run_id
        errors.add(:base, "claim and source must belong to the same research run")
      end

      if research_claim.theme != research_source.theme
        errors.add(:base, "claim and source must belong to the same theme")
      end
    end
end

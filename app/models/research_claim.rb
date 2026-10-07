# frozen_string_literal: true

class ResearchClaim < ApplicationRecord
  CLAIM_KINDS = %w[
    factual_evidence
    forecast
    opinion
    assumption
    promotional_material
    investment_recommendation
  ].freeze

  STANCES = %w[support challenge mixed neutral].freeze
  STATUSES = %w[draft verified conflicted insufficient_evidence rejected].freeze

  belongs_to :research_run
  has_many :research_evidences, dependent: :destroy
  has_many :research_sources, through: :research_evidences
  has_many :investment_recommendation_claims, dependent: :destroy
  has_many :investment_recommendations, through: :investment_recommendation_claims

  validates :theme, inclusion: { in: ResearchSource::THEMES }
  validates :claim_kind, inclusion: { in: CLAIM_KINDS }
  validates :statement, :as_of_at, presence: true
  validates :stance, inclusion: { in: STANCES }
  validates :status, inclusion: { in: STATUSES }
  validates :confidence,
            numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 1 },
            allow_nil: true

  def independently_cross_checked?
    research_evidences
      .joins(:research_source)
      .where(independent: true, research_sources: { status: "accepted" })
      .select("research_sources.publisher")
      .distinct
      .count >= 2
  end
end

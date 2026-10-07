# frozen_string_literal: true

class ResearchSource < ApplicationRecord
  THEMES = %w[
    asset_manager_concentration
    debt_monetary_regime
    ai_adoption_productivity
    bitcoin_financial_system
    ai_cooling_power_management
    grid_electrification
    ai_networking
  ].freeze

  SOURCE_TYPES = %w[
    peer_reviewed
    university_research
    central_bank
    government
    multilateral
    regulator
    primary_data
    institutional_research
    company_filing
    earnings_call
    industry_research
    standards_body
    specialist_research
    financial_journalism
    podcast_interview
    opinion
    promotional
  ].freeze

  THESIS_POSITIONS = %w[support challenge mixed neutral].freeze
  STATUSES = %w[accepted downgraded rejected].freeze

  belongs_to :research_run
  belongs_to :raw_source_record, optional: true

  has_many :research_evidences, dependent: :destroy
  has_many :research_claims, through: :research_evidences

  validates :theme, inclusion: { in: THEMES }
  validates :source_type, inclusion: { in: SOURCE_TYPES }
  validates :title, :publisher, :url, :retrieved_at, presence: true
  validates :source_tier, inclusion: { in: 1..4 }
  validates :thesis_position, inclusion: { in: THESIS_POSITIONS }
  validates :status, inclusion: { in: STATUSES }
  validates :authority, :evidence_quality, :independence, :methodological_transparency,
            :relevance, :recency,
            numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: 5 }
  validates :overall_quality_score,
            numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 5 }

  before_validation :calculate_overall_quality_score

  scope :accepted, -> { where(status: "accepted") }
  scope :ranked, -> { order(source_tier: :asc, overall_quality_score: :desc, publication_date: :desc) }

  def calculate_overall_quality_score
    scores = [
      authority,
      evidence_quality,
      independence,
      methodological_transparency,
      relevance,
      recency
    ]
    return if scores.any?(&:nil?)

    self.overall_quality_score = (scores.sum.to_d / scores.length).round(2)
  end
end

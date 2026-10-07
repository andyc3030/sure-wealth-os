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
    peer_reviewed_academic
    university_research
    regulator_government_multilateral
    primary_data_institution
    company_filing
    institutional_research
    specialist_research
    financial_journalism
    expert_podcast
    opinion
    promotional
    other
  ].freeze

  STATUSES = %w[accepted downgraded rejected].freeze

  RANKING_TIERS = {
    "peer_reviewed_academic" => 0,
    "university_research" => 0,
    "regulator_government_multilateral" => 0,
    "primary_data_institution" => 0,
    "company_filing" => 1,
    "institutional_research" => 1,
    "specialist_research" => 2,
    "financial_journalism" => 3,
    "expert_podcast" => 4,
    "opinion" => 5,
    "promotional" => 6,
    "other" => 6
  }.freeze

  ACADEMIC_TYPES = %w[peer_reviewed_academic university_research].freeze
  PRIMARY_OR_INSTITUTIONAL_TYPES = %w[
    peer_reviewed_academic
    university_research
    regulator_government_multilateral
    primary_data_institution
    company_filing
    institutional_research
  ].freeze
  INDUSTRY_TYPES = %w[company_filing institutional_research specialist_research].freeze

  belongs_to :family
  belongs_to :raw_source_record, optional: true
  has_many :research_source_scores, dependent: :destroy
  has_many :research_claims, dependent: :destroy

  validates :theme, inclusion: { in: THEMES }
  validates :source_type, inclusion: { in: SOURCE_TYPES }
  validates :status, inclusion: { in: STATUSES }
  validates :title, :publisher, :url, :accessed_at, presence: true
  validate :promotional_source_is_not_accepted
  validate :commercial_conflict_is_disclosed
  validate :raw_source_record_matches_family

  scope :eligible, -> { where.not(status: "rejected") }
  scope :accepted, -> { where(status: "accepted") }

  def ranking_tier
    RANKING_TIERS.fetch(source_type, RANKING_TIERS["other"])
  end

  def latest_score
    research_source_scores.order(as_of_date: :desc, created_at: :desc).first
  end

  def latest_overall_score
    latest_score&.overall_score
  end

  def independence_key
    independence_group.presence || publisher
  end

  private

    def promotional_source_is_not_accepted
      return unless promotional? || source_type == "promotional"
      return unless status == "accepted"

      errors.add(:status, "must be downgraded or rejected for promotional sources")
    end

    def commercial_conflict_is_disclosed
      return unless commercial_conflict?
      return if conflict_notes.present?

      errors.add(:conflict_notes, "must disclose the commercial conflict")
    end

    def raw_source_record_matches_family
      return if raw_source_record.nil? || raw_source_record.family_id == family_id

      errors.add(:raw_source_record, "must belong to the same family")
    end
end

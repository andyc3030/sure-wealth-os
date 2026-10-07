# frozen_string_literal: true

class ResearchClaim < ApplicationRecord
  CLAIM_TYPES = %w[fact forecast opinion assumption promotional recommendation].freeze
  THESIS_EFFECTS = %w[supports challenges neutral mixed].freeze
  STATUSES = %w[accepted downgraded rejected].freeze

  belongs_to :family
  belongs_to :research_source
  belongs_to :raw_source_record, optional: true

  validates :theme, inclusion: { in: ResearchSource::THEMES }
  validates :claim_type, inclusion: { in: CLAIM_TYPES }
  validates :thesis_effect, inclusion: { in: THESIS_EFFECTS }
  validates :status, inclusion: { in: STATUSES }
  validates :claim_summary, presence: true
  validates :confidence,
            numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 1 },
            allow_nil: true
  validate :theme_matches_source
  validate :source_matches_family
  validate :raw_source_record_matches_family

  private

    def theme_matches_source
      return if research_source.nil? || theme == research_source.theme

      errors.add(:theme, "must match the research source theme")
    end

    def source_matches_family
      return if research_source.nil? || research_source.family_id == family_id

      errors.add(:research_source, "must belong to the same family")
    end

    def raw_source_record_matches_family
      return if raw_source_record.nil? || raw_source_record.family_id == family_id

      errors.add(:raw_source_record, "must belong to the same family")
    end
end

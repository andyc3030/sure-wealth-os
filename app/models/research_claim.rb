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

  private

    def theme_matches_source
      return if research_source.nil? || theme == research_source.theme

      errors.add(:theme, "must match the research source theme")
    end
end

# frozen_string_literal: true

class ResearchSourceScore < ApplicationRecord
  SCORE_FIELDS = %i[
    authority_score
    evidence_quality_score
    independence_score
    methodology_transparency_score
    relevance_score
    recency_score
  ].freeze

  belongs_to :family
  belongs_to :research_source

  validates :as_of_date, presence: true
  validates :research_source_id, uniqueness: { scope: :as_of_date }
  validates(*SCORE_FIELDS, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 5 })
  validates :overall_score, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 5 }

  before_validation :calculate_overall_score
  validate :source_matches_family

  private

    def calculate_overall_score
      values = SCORE_FIELDS.map { |field| public_send(field) }
      return if values.any?(&:nil?)

      self.overall_score = (values.sum(&:to_d) / values.length).round(2)
    end

    def source_matches_family
      return if research_source.nil? || research_source.family_id == family_id

      errors.add(:research_source, "must belong to the same family")
    end
end

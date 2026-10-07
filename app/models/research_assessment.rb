# frozen_string_literal: true

class ResearchAssessment < ApplicationRecord
  belongs_to :family
  has_many :investment_recommendations, dependent: :destroy

  validates :theme, inclusion: { in: ResearchSource::THEMES }
  validates :as_of_date, :methodology_version, :evidence_summary, :uncertainty, :falsification_conditions, presence: true
  validates :source_count, :challenging_source_count, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  before_update :prevent_mutation
  before_destroy :prevent_mutation

  private

    def prevent_mutation
      errors.add(:base, "research assessments are append-only; create a new as-of version")
      throw(:abort)
    end
end

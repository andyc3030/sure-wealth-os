# frozen_string_literal: true

class ResearchRun < ApplicationRecord
  STATUSES = %w[draft researching complete rejected].freeze

  belongs_to :family
  has_many :research_sources, dependent: :destroy
  has_many :research_claims, dependent: :destroy
  has_many :research_theme_assessments, dependent: :destroy
  has_many :investment_recommendations, dependent: :destroy

  validates :as_of_at, :methodology_version, presence: true
  validates :status, inclusion: { in: STATUSES }
end

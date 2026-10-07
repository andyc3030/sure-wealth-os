# frozen_string_literal: true

class ResearchThemeAssessment < ApplicationRecord
  STATUSES = %w[draft reviewable complete insufficient_evidence rejected].freeze

  belongs_to :research_run

  validates :theme, inclusion: { in: ResearchSource::THEMES }
  validates :evidence_summary, :uncertainty_summary, :existing_portfolio_exposure, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :theme, uniqueness: { scope: :research_run_id }

  def evidence_gate
    WealthOs::Research::ThemeCoverageValidator.call(
      research_run: research_run,
      theme: theme
    )
  end
end

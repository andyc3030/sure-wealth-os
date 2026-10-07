# frozen_string_literal: true

class InvestmentRecommendation < ApplicationRecord
  ACTIONS = %w[increase hold reduce exit consider avoid].freeze
  SLEEVES = %w[core aggressive_scenario].freeze
  STATUSES = %w[draft reviewable reviewed rejected expired].freeze
  PORTFOLIO_STATUSES = %w[existing missing unknown].freeze

  belongs_to :research_run
  belongs_to :security, optional: true
  belongs_to :price_raw_source_record, class_name: "RawSourceRecord", optional: true

  has_many :investment_recommendation_claims, dependent: :destroy
  has_many :research_claims, through: :investment_recommendation_claims

  validates :theme, inclusion: { in: ResearchSource::THEMES }
  validates :company_name, :action, :sleeve, :role_in_thesis, :valuation_context,
            :structural_thesis, :correlation_context, :competitive_position,
            :capital_intensity, :cash_generation_quality, :balance_sheet_quality,
            :as_of_at, presence: true
  validates :action, inclusion: { in: ACTIONS }
  validates :sleeve, inclusion: { in: SLEEVES }
  validates :status, inclusion: { in: STATUSES }
  validates :portfolio_status, inclusion: { in: PORTFOLIO_STATUSES }
  validates :confidence,
            numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 1 },
            allow_nil: true
  validates :price_currency, length: { is: 3 }, allow_nil: true
  validates :current_weight_pct, :proposed_weight_pct,
            numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 },
            allow_nil: true
  validate :price_provenance_complete
  validate :entry_zone_order
  validate :action_matches_portfolio_status
  validate :weight_requires_existing_position

  def price_provenance_complete
    price_fields = [ current_price, price_currency, price_as_of_at, price_raw_source_record_id ]
    return if price_fields.all?(&:nil?)
    return if price_fields.none?(&:nil?)

    errors.add(:current_price, "requires currency, as-of timestamp and raw source provenance")
  end

  def action_matches_portfolio_status
    existing_actions = %w[increase hold reduce exit]
    return unless existing_actions.include?(action)
    return if portfolio_status == "existing"

    errors.add(:portfolio_status, "must be existing for increase/hold/reduce/exit")
  end

  def weight_requires_existing_position
    return if current_weight_pct.nil? || portfolio_status == "existing"

    errors.add(:current_weight_pct, "requires an existing portfolio position")
  end

  def entry_zone_order
    return if preferred_entry_low.nil? || preferred_entry_high.nil?
    return if preferred_entry_low <= preferred_entry_high

    errors.add(:preferred_entry_low, "must not exceed preferred entry high")
  end
end

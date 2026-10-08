# frozen_string_literal: true

class InvestmentRecommendation < ApplicationRecord
  ACTIONS = %w[increase hold reduce exit consider avoid].freeze
  ALLOCATION_SLEEVES = %w[core aggressive none].freeze
  TECHNICAL_GATE_STATUSES = %w[pass fail insufficient_evidence not_evaluated].freeze
  NEW_CAPITAL_ACTIONS = %w[increase consider].freeze

  belongs_to :family
  belongs_to :research_assessment

  validates :action, inclusion: { in: ACTIONS }
  validates :allocation_sleeve, inclusion: { in: ALLOCATION_SLEEVES }
  validates :technical_gate_status, inclusion: { in: TECHNICAL_GATE_STATUSES }
  validates :company, presence: true
  validates :evidence_quality_score,
            numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 5 },
            allow_nil: true
  validate :new_capital_recommendation_has_full_investment_case
  validate :assessment_has_sufficient_evidence
  validate :deterministic_evidence_gate_passes
  validate :assessment_matches_family

  before_update :prevent_mutation
  before_destroy :prevent_mutation

  private

    def new_capital_recommendation_has_full_investment_case
      return unless action.in?(NEW_CAPITAL_ACTIONS)

      {
        valuation_analysis: valuation_analysis,
        competitive_position_analysis: competitive_position_analysis,
        capital_intensity_analysis: capital_intensity_analysis,
        cash_generation_analysis: cash_generation_analysis,
        balance_sheet_analysis: balance_sheet_analysis,
        downside_analysis: downside_analysis,
        structural_thesis: structural_thesis,
        near_term_catalyst: near_term_catalyst,
        principal_risks: principal_risks,
        correlation_context: correlation_context
      }.each do |field, value|
        errors.add(field, "is required for increase/consider recommendations") if value.blank?
      end

      if reference_price.blank? || price_currency.blank? || price_as_of.blank? || price_source.blank?
        errors.add(:reference_price, "requires sourced, timestamped current price context")
      end

      if allocation_sleeve == "none"
        errors.add(:allocation_sleeve, "must be core or aggressive for increase/consider recommendations")
      end
    end

    def assessment_has_sufficient_evidence
      return unless action.in?(NEW_CAPITAL_ACTIONS)
      return if research_assessment.nil? || !research_assessment.insufficient_evidence?

      errors.add(:research_assessment, "has insufficient evidence for increase/consider recommendations")
    end

    def deterministic_evidence_gate_passes
      return unless action.in?(NEW_CAPITAL_ACTIONS)
      return if family.nil? || research_assessment.nil?

      result = WealthOs::Research::EvidenceGate.call(
        theme: research_assessment.theme,
        sources: ResearchSource.where(family_id: family_id, theme: research_assessment.theme).to_a,
        claims: ResearchClaim.where(family_id: family_id, theme: research_assessment.theme).to_a
      )
      return if result.passed

      errors.add(
        :research_assessment,
        "does not pass deterministic evidence gate: #{result.deficiencies.join("; ")}"
      )
    end

    def assessment_matches_family
      return if research_assessment.nil? || research_assessment.family_id == family_id

      errors.add(:research_assessment, "must belong to the same family")
    end

    def prevent_mutation
      errors.add(:base, "investment recommendations are append-only; create a new recommendation version")
      throw(:abort)
    end
end

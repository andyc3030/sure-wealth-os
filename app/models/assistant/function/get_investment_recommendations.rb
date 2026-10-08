# frozen_string_literal: true

class Assistant::Function::GetInvestmentRecommendations < Assistant::Function
  class << self
    def name
      "get_investment_recommendations"
    end

    def description
      <<~INSTRUCTIONS
        Read stored Wealth OS investment recommendations that were created under
        the deterministic research-governance policy.

        Use this only to explain existing advisory records. Never invent a new
        action, upgrade conviction, or turn a recommendation into a trade,
        transfer, payment or other execution instruction.
      INSTRUCTIONS
    end
  end

  def strict_mode?
    false
  end

  def params_schema
    build_schema(
      required: [],
      properties: {
        theme: {
          type: "string",
          enum: ResearchSource::THEMES,
          description: "Optional research theme"
        },
        action: {
          type: "string",
          enum: InvestmentRecommendation::ACTIONS,
          description: "Optional stored advisory action filter"
        },
        ticker: {
          type: "string",
          description: "Optional exact ticker filter"
        }
      }
    )
  end

  def call(params = {})
    return unavailable unless WealthOs::Dashboard::AccessPolicy.allowed?(user: user, family: family)

    theme = params["theme"].presence
    action = params["action"].presence
    ticker = params["ticker"].presence

    if theme && !ResearchSource::THEMES.include?(theme)
      return { "error" => "unsupported_research_theme", "hint" => "Choose one of: #{ResearchSource::THEMES.join(", ")}" }
    end
    if action && !InvestmentRecommendation::ACTIONS.include?(action)
      return { "error" => "unsupported_recommendation_action", "hint" => "Choose one of: #{InvestmentRecommendation::ACTIONS.join(", ")}" }
    end

    scope = InvestmentRecommendation.where(family_id: family.id).includes(:research_assessment)
    scope = scope.where(action: action) if action
    scope = scope.joins(:research_assessment).where(research_assessments: { theme: theme }) if theme
    scope = scope.where("UPPER(investment_recommendations.ticker) = ?", ticker.upcase) if ticker

    {
      "advisory_only" => true,
      "authoritative_accounting" => false,
      "stored_recommendations_only" => true,
      "execution_capability" => false,
      "recommendations" => scope.order(created_at: :desc, id: :desc).limit(50).map { |recommendation|
        serialize(recommendation)
      }
    }
  end

  private

    def serialize(recommendation)
      assessment = recommendation.research_assessment
      {
        "id" => recommendation.id,
        "assessment_id" => assessment.id,
        "theme" => assessment.theme,
        "assessment_as_of_date" => assessment.as_of_date.iso8601,
        "assessment_insufficient_evidence" => assessment.insufficient_evidence,
        "action" => recommendation.action,
        "ticker" => recommendation.ticker,
        "company" => recommendation.company,
        "role_in_thesis" => recommendation.role_in_thesis,
        "reference_price" => recommendation.reference_price&.to_d&.to_s("F"),
        "price_currency" => recommendation.price_currency,
        "price_as_of" => recommendation.price_as_of&.iso8601,
        "price_source" => recommendation.price_source,
        "entry_zone_low" => recommendation.entry_zone_low&.to_d&.to_s("F"),
        "entry_zone_high" => recommendation.entry_zone_high&.to_d&.to_s("F"),
        "invalidation_level" => recommendation.invalidation_level&.to_d&.to_s("F"),
        "structural_thesis" => recommendation.structural_thesis,
        "near_term_catalyst" => recommendation.near_term_catalyst,
        "principal_risks" => recommendation.principal_risks,
        "correlation_context" => recommendation.correlation_context,
        "allocation_sleeve" => recommendation.allocation_sleeve,
        "valuation_analysis" => recommendation.valuation_analysis,
        "competitive_position_analysis" => recommendation.competitive_position_analysis,
        "capital_intensity_analysis" => recommendation.capital_intensity_analysis,
        "cash_generation_analysis" => recommendation.cash_generation_analysis,
        "balance_sheet_analysis" => recommendation.balance_sheet_analysis,
        "downside_analysis" => recommendation.downside_analysis,
        "evidence_quality_score" => recommendation.evidence_quality_score&.to_d&.to_s("F"),
        "technical_gate_status" => recommendation.technical_gate_status,
        "technical_gate_details" => recommendation.technical_gate_details,
        "created_at" => recommendation.created_at.iso8601
      }
    end

    def unavailable
      {
        "error" => "research_intelligence_not_available",
        "hint" => "Family-wide research intelligence is available to family administrators."
      }
    end
end

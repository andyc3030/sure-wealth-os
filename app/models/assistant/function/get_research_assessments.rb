# frozen_string_literal: true

class Assistant::Function::GetResearchAssessments < Assistant::Function
  class << self
    def name
      "get_research_assessments"
    end

    def description
      <<~INSTRUCTIONS
        Read stored Wealth OS research assessments.

        Use this for evidence summaries, uncertainty, falsification conditions,
        source coverage and theme-level research status. These are advisory
        research records, not authoritative accounting values. Explain stored
        assessments; do not invent missing evidence or create recommendations.
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
          description: "Optional research theme; omit to return the latest assessment for every theme"
        }
      }
    )
  end

  def call(params = {})
    return unavailable unless WealthOs::Dashboard::AccessPolicy.allowed?(user: user, family: family)

    theme = params["theme"].presence
    if theme && !ResearchSource::THEMES.include?(theme)
      return {
        "error" => "unsupported_research_theme",
        "hint" => "Choose one of: #{ResearchSource::THEMES.join(", ")}"
      }
    end

    assessments = if theme
      [ assessment_scope.where(theme: theme).order(as_of_date: :desc, created_at: :desc).first ].compact
    else
      latest_by_theme
    end

    {
      "advisory_only" => true,
      "authoritative_accounting" => false,
      "execution_capability" => false,
      "assessments" => assessments.map { |assessment| serialize(assessment) }
    }
  end

  private

    def assessment_scope
      ResearchAssessment.where(family_id: family.id)
    end

    def latest_by_theme
      ordered = assessment_scope.order(as_of_date: :desc, created_at: :desc).to_a
      ResearchSource::THEMES.filter_map { |theme| ordered.find { |assessment| assessment.theme == theme } }
    end

    def serialize(assessment)
      {
        "id" => assessment.id,
        "theme" => assessment.theme,
        "as_of_date" => assessment.as_of_date.iso8601,
        "methodology_version" => assessment.methodology_version,
        "evidence_summary" => assessment.evidence_summary,
        "uncertainty" => assessment.uncertainty,
        "falsification_conditions" => assessment.falsification_conditions,
        "structural_bottlenecks" => assessment.structural_bottlenecks,
        "quality_exposures" => assessment.quality_exposures,
        "narrative_beneficiaries" => assessment.narrative_beneficiaries,
        "portfolio_coverage" => assessment.portfolio_coverage,
        "new_positions" => assessment.new_positions,
        "top_source_ids" => assessment.top_source_ids,
        "source_count" => assessment.source_count,
        "challenging_source_count" => assessment.challenging_source_count,
        "insufficient_evidence" => assessment.insufficient_evidence
      }
    end

    def unavailable
      {
        "error" => "research_intelligence_not_available",
        "hint" => "Family-wide research intelligence is available to family administrators."
      }
    end
end

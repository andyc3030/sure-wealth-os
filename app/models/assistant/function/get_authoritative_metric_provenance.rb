# frozen_string_literal: true

class Assistant::Function::GetAuthoritativeMetricProvenance < Assistant::Function
  class << self
    def name
      "get_authoritative_metric_provenance"
    end

    def description
      <<~INSTRUCTIONS
        Read deterministic provenance for one Wealth OS authoritative-close metric.

        Use this when the user asks why an authoritative number has its value,
        how it was calculated, or what source components support it. This is
        read-only lineage; never invent missing evidence.
      INSTRUCTIONS
    end
  end

  def strict_mode?
    false
  end

  def params_schema
    build_schema(
      required: [ "metric" ],
      properties: {
        metric: {
          type: "string",
          enum: WealthOs::Dashboard::ProvenanceBuilder::METRICS,
          description: "Authoritative metric to trace"
        },
        close_date: {
          type: "string",
          description: "Optional close date in YYYY-MM-DD format; omit for latest"
        }
      }
    )
  end

  def call(params = {})
    metric = params["metric"].to_s
    unless WealthOs::Dashboard::ProvenanceBuilder::METRICS.include?(metric)
      return {
        "error" => "unsupported_metric",
        "hint" => "Choose one of: #{WealthOs::Dashboard::ProvenanceBuilder::METRICS.join(", ")}"
      }
    end

    snapshot = resolve_snapshot(params["close_date"])
    return no_snapshot_result(params["close_date"]) unless snapshot

    WealthOs::Dashboard::ProvenanceBuilder.call(snapshot: snapshot, metric: metric)
  rescue ArgumentError
    {
      "error" => "invalid_date",
      "hint" => "Use close_date in YYYY-MM-DD format, or omit it for the latest authoritative close."
    }
  end

  private
    def resolve_snapshot(raw_date)
      scope = DailyCloseSnapshot.where(family_id: family.id)

      if raw_date.present?
        scope.find_by(close_date: Date.iso8601(raw_date.to_s))
      else
        scope.order(close_date: :desc, created_at: :desc).first
      end
    end

    def no_snapshot_result(raw_date)
      {
        "error" => "authoritative_close_not_found",
        "close_date" => raw_date,
        "hint" => raw_date.present? ?
          "No authoritative close exists for that date. Ask for the latest close or another YYYY-MM-DD date." :
          "No authoritative daily close exists yet for this family."
      }
    end
end

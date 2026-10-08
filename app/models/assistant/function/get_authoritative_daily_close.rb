# frozen_string_literal: true

class Assistant::Function::GetAuthoritativeDailyClose < Assistant::Function
  class << self
    def name
      "get_authoritative_daily_close"
    end

    def description
      <<~INSTRUCTIONS
        Read the immutable Wealth OS authoritative daily close.

        Use this for authoritative dashboard totals, income states, contractual
        cash forecasts, liquid/investable net worth, close quality and confidence.
        The returned values are deterministic close outputs: explain them, do not
        recompute or replace them with live balances.
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
        close_date: {
          type: "string",
          description: "Optional authoritative close date in YYYY-MM-DD format; omit for latest"
        }
      }
    )
  end

  def call(params = {})
    unless WealthOs::Dashboard::AccessPolicy.allowed?(user: user, family: family)
      return {
        "error" => "authoritative_close_not_available",
        "hint" => "Family-wide authoritative close data is available to family administrators."
      }
    end

    snapshot = resolve_snapshot(params["close_date"])
    return no_snapshot_result(params["close_date"]) unless snapshot

    WealthOs::Dashboard::SummaryBuilder.call(snapshot: snapshot).as_json.merge(
      "authoritative" => true,
      "immutable" => true,
      "explanation_rule" => "Explain these deterministic values; do not recompute or silently override them with live data."
    )
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

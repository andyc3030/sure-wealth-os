# frozen_string_literal: true

module WealthOs
  module DailyClose
    class ActionNowBuilder
      def self.call(quality:, forecast:)
        actions = []
        details = quality.details

        if details.fetch("open_source_conflicts").positive?
          actions << {
            "action" => "REVIEW",
            "priority" => details.fetch("material_open_source_conflicts").positive? ? "critical" : "high",
            "reason" => "open_source_conflicts",
            "count" => details.fetch("open_source_conflicts")
          }
        end

        reconciliation_count =
          details.fetch("failed_reconciliations") + details.fetch("reconciliation_warnings")
        if reconciliation_count.positive?
          actions << {
            "action" => "RECONCILE",
            "priority" => details.fetch("material_failed_reconciliations").positive? ? "critical" : "high",
            "reason" => "reconciliation_exceptions",
            "count" => reconciliation_count
          }
        end

        if details.fetch("failed_or_stale_syncs").positive?
          actions << {
            "action" => "RETRY SYNC",
            "priority" => "critical",
            "reason" => "failed_or_stale_syncs",
            "count" => details.fetch("failed_or_stale_syncs")
          }
        end

        if details.fetch("stale_fx_rates").positive?
          actions << {
            "action" => "WATCH",
            "priority" => "medium",
            "reason" => "stale_fx_rates",
            "count" => details.fetch("stale_fx_rates")
          }
        end

        thirty_day = forecast.horizons.fetch(30)
        if thirty_day.fetch("net_cash").negative?
          actions << {
            "action" => "WATCH CASH",
            "priority" => "high",
            "reason" => "negative_30_day_contractual_cash_forecast",
            "amount" => thirty_day.fetch("net_cash").to_s("F")
          }
        end

        actions << {
          "action" => "NO ACTION",
          "priority" => "none",
          "reason" => "authoritative_close_has_no_rule_based_exceptions"
        } if actions.empty?

        actions.freeze
      end
    end
  end
end

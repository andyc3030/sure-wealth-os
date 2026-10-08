# frozen_string_literal: true

module WealthOs
  module Dashboard
    class ProvenanceBuilder
      UnsupportedMetric = Class.new(ArgumentError)

      METRICS = %w[
        gross_assets total_liabilities net_worth liquid_net_worth investable_net_worth
        income_forecast income_accrued income_declared income_received
        income_equivalent_annual income_equivalent_monthly income_equivalent_daily
        forecast_7_income forecast_7_liabilities forecast_7_net
        forecast_30_income forecast_30_liabilities forecast_30_net
        forecast_90_income forecast_90_liabilities forecast_90_net
        forecast_365_income forecast_365_liabilities forecast_365_net confidence
      ].freeze

      def self.call(snapshot:, metric:)
        new(snapshot: snapshot, metric: metric).call
      end

      def initialize(snapshot:, metric:)
        @snapshot = snapshot
        @metric = metric.to_s
        raise UnsupportedMetric, "unsupported authoritative metric: #{@metric}" unless METRICS.include?(@metric)
      end

      def call
        detail = metric_detail
        {
          "snapshot_id" => snapshot.id,
          "snapshot_digest" => snapshot.payload_sha256,
          "close_date" => snapshot.close_date.iso8601,
          "cutoff_at" => snapshot.cutoff_at.iso8601,
          "reporting_currency" => snapshot.reporting_currency,
          "authoritative" => true,
          "metric" => metric,
          "value" => serialized_value(detail.fetch(:value)),
          "calculation" => detail.fetch(:calculation),
          "components" => detail.fetch(:components),
          "lineage_status" => manifest.present? ? "captured_at_close" : "legacy_snapshot_without_phase6_manifest"
        }
      end

      private
        attr_reader :snapshot, :metric

        def metric_detail
          case metric
          when "gross_assets"
            monetary_detail(summary.gross_assets,
              "sum reporting-currency value of authoritative asset account rows",
              valuation_rows.select { |row| row["classification"] == "asset" })
          when "total_liabilities"
            monetary_detail(summary.total_liabilities,
              "sum reporting-currency value of authoritative liability account rows",
              valuation_rows.select { |row| row["classification"] == "liability" })
          when "net_worth"
            monetary_detail(summary.net_worth, "gross assets minus total liabilities", {
              "gross_assets" => summary.gross_assets.to_s("F"),
              "total_liabilities" => summary.total_liabilities.to_s("F")
            })
          when "liquid_net_worth", "investable_net_worth"
            type_policy_detail(metric, summary.public_send(metric))
          when /Aincome_(forecast|accrued|declared|received)z/
            state = Regexp.last_match(1)
            monetary_detail(summary.income_by_state.fetch(state),
              "sum net economic income for close-time income events in state #{state}",
              Array(manifest["income_events"]).select { |row| row["state"] == state })
          when /Aincome_equivalent_(annual|monthly|daily)z/
            period = Regexp.last_match(1)
            divisor = { "annual" => 1, "monthly" => 12, "daily" => 365 }.fetch(period)
            monetary_detail(summary.income_equivalents.fetch(period),
              "365-day contractual forecast income divided by #{divisor}", {
                "forecast_365_income" => summary.cash_forecasts.fetch(365).fetch("income").to_s("F"),
                "divisor" => divisor, "basis" => summary.income_equivalents.fetch("basis")
              })
          when /Aforecast_(7|30|90|365)z/
            days = Regexp.last_match(1).to_i
            row = summary.cash_forecasts.fetch(days)
            monetary_detail(row.fetch("net_cash"),
              "contractual income through #{days} days minus scheduled liability payments through the same horizon",
              forecast_components(days))
          when "confidence"
            { value: summary.confidence,
              calculation: "deterministic Phase 5 quality gate confidence: PASS 1.00, WARNING 0.75",
              components: { "quality" => snapshot.payload["quality"] || {},
                            "quality_lineage" => manifest["quality"] || {} } }
          else
            raise UnsupportedMetric, "unsupported authoritative metric: #{metric}"
          end
        end

        def monetary_detail(value, calculation, components)
          { value: value, calculation: calculation, components: components }
        end

        def type_policy_detail(policy_name, value)
          policy = summary.classification_policy.fetch(policy_name)
          assets = valuation_rows.select do |row|
            row["classification"] == "asset" && policy.fetch("asset_types").include?(account_type_for(row))
          end
          liabilities = valuation_rows.select { |row| row["classification"] == "liability" }

          monetary_detail(value,
            "#{policy.fetch("formula")}; eligible asset types: #{policy.fetch("asset_types").join(", ")}",
            { "eligible_assets" => assets, "liabilities" => liabilities, "policy" => policy })
        end

        def forecast_components(days)
          through_date = snapshot.close_date + days.days
          income = Array(manifest["income_events"]).select do |row|
            next false unless %w[forecast accrued declared].include?(row["state"])
            due = due_date(row)
            due && due > snapshot.close_date && due <= through_date
          end
          liabilities = Array(manifest["scheduled_liability_payments"]).select do |row|
            date = parse_date(row["payment_date"])
            date && date <= through_date
          end

          {
            "through_date" => through_date.iso8601,
            "income_events" => income,
            "scheduled_liability_payments" => liabilities,
            "reported_forecast" => summary.cash_forecasts.fetch(days).transform_values { |value|
              value.is_a?(BigDecimal) ? value.to_s("F") : value
            }
          }
        end

        def due_date(row)
          parse_date(row["payable_on"] || row["expected_on"] || row["accrual_end_date"])
        end

        def parse_date(value)
          return nil if value.blank?
          Date.iso8601(value.to_s)
        rescue ArgumentError
          nil
        end

        def summary
          @summary ||= SummaryBuilder.call(snapshot: snapshot)
        end

        def manifest
          @manifest ||= snapshot.payload["provenance"] || {}
        end

        def valuation_rows
          @valuation_rows ||= Array(snapshot.payload.dig("valuation", "accounts"))
        end

        def account_type_for(row)
          row["accountable_type"].presence || account_types_by_id[row["account_id"].to_s]
        end

        def account_types_by_id
          @account_types_by_id ||= begin
            ids = valuation_rows.filter_map { |row| row["account_id"] }.uniq
            Account.where(family_id: snapshot.family_id, id: ids)
              .pluck(:id, :accountable_type).to_h.transform_keys(&:to_s)
          end
        end

        def serialized_value(value)
          value.is_a?(BigDecimal) ? value.to_s("F") : value
        end
    end
  end
end

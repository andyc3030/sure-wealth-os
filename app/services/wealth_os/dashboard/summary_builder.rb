# frozen_string_literal: true

module WealthOs
  module Dashboard
    class SummaryBuilder
      LIQUID_ACCOUNT_TYPES = %w[Depository].freeze
      INVESTABLE_ACCOUNT_TYPES = %w[Depository Investment Crypto].freeze

      CLASSIFICATION_POLICY = {
        "liquid_net_worth" => {
          "asset_types" => LIQUID_ACCOUNT_TYPES,
          "formula" => "liquid assets minus all liabilities"
        },
        "investable_net_worth" => {
          "asset_types" => INVESTABLE_ACCOUNT_TYPES,
          "formula" => "investable assets minus all liabilities"
        }
      }.freeze

      Result = Data.define(
        :snapshot_id, :close_date, :cutoff_at, :reporting_currency, :quality_status, :confidence,
        :gross_assets, :total_liabilities, :net_worth,
        :liquid_assets, :liquid_net_worth, :investable_assets, :investable_net_worth,
        :income_by_state, :income_equivalents, :cash_forecasts, :data_completeness,
        :classification_policy, :action_now, :performance
      ) do
        def as_json(*)
          {
            "snapshot_id" => snapshot_id,
            "close_date" => close_date.iso8601,
            "cutoff_at" => cutoff_at.iso8601,
            "reporting_currency" => reporting_currency,
            "quality_status" => quality_status,
            "confidence" => confidence.to_s("F"),
            "gross_assets" => gross_assets.to_s("F"),
            "total_liabilities" => total_liabilities.to_s("F"),
            "net_worth" => net_worth.to_s("F"),
            "liquid_assets" => decimal_string(liquid_assets),
            "liquid_net_worth" => decimal_string(liquid_net_worth),
            "investable_assets" => decimal_string(investable_assets),
            "investable_net_worth" => decimal_string(investable_net_worth),
            "income_by_state" => income_by_state.transform_values { |value| value.to_s("F") },
            "income_equivalents" => income_equivalents.transform_values { |value|
              value.is_a?(BigDecimal) ? value.to_s("F") : value
            },
            "cash_forecasts" => cash_forecasts.transform_keys(&:to_s).transform_values { |row|
              row.transform_values { |value| value.is_a?(BigDecimal) ? value.to_s("F") : value }
            },
            "data_completeness" => data_completeness,
            "classification_policy" => classification_policy,
            "action_now" => action_now,
            "performance" => performance
          }
        end

        private

          def decimal_string(value)
            value&.to_s("F")
          end
      end

      class << self
        def latest(family:)
          snapshot = DailyCloseSnapshot.where(family_id: family.id)
            .order(close_date: :desc, created_at: :desc).first
          snapshot ? call(snapshot: snapshot) : nil
        end

        def call(snapshot:)
          new(snapshot: snapshot).call
        end
      end

      def initialize(snapshot:)
        @snapshot = snapshot
      end

      def call
        payload = snapshot.payload || {}
        rows = Array(payload.dig("valuation", "accounts"))
        classification_complete = rows
          .select { |row| row["classification"] == "asset" }
          .all? { |row| row["accountable_type"].present? }

        liquid_assets = sum_asset_rows(rows, types: LIQUID_ACCOUNT_TYPES) if classification_complete
        investable_assets = sum_asset_rows(rows, types: INVESTABLE_ACCOUNT_TYPES) if classification_complete
        total_liabilities = snapshot.total_liabilities.to_d

        income_by_state = IncomeEvent::STATES.to_h do |state|
          [ state, decimal(payload.dig("income_and_liabilities", "income_by_state", state)) ]
        end

        cash_forecasts = build_cash_forecasts(payload)
        annual_income = cash_forecasts.fetch(365).fetch("income")
        quality_details = payload.dig("quality", "details") || {}

        Result.new(
          snapshot.id, snapshot.close_date, snapshot.cutoff_at, snapshot.reporting_currency,
          snapshot.quality_status, snapshot.confidence.to_d,
          snapshot.gross_assets.to_d, total_liabilities, snapshot.net_worth.to_d,
          liquid_assets, liquid_assets && (liquid_assets - total_liabilities),
          investable_assets, investable_assets && (investable_assets - total_liabilities),
          income_by_state.freeze,
          {
            "basis" => "365_day_contractual_income_forecast",
            "annual" => annual_income,
            "monthly" => annual_income / 12,
            "daily" => annual_income / 365
          }.freeze,
          cash_forecasts.freeze,
          {
            "valuation_account_count" => rows.size,
            "exact_balance_coverage" => "1.0",
            "unclassified_snapshot_accounts" => rows.count { |row|
              row["classification"] == "asset" && row["accountable_type"].blank?
            },
            "open_source_conflicts" => quality_details.fetch("open_source_conflicts", 0),
            "failed_reconciliations" => quality_details.fetch("failed_reconciliations", 0),
            "reconciliation_warnings" => quality_details.fetch("reconciliation_warnings", 0),
            "failed_or_stale_syncs" => quality_details.fetch("failed_or_stale_syncs", 0),
            "stale_fx_rates" => quality_details.fetch("stale_fx_rates", 0),
            "undated_income_count" => payload.dig("forecast", "undated_income_count").to_i
          }.freeze,
          CLASSIFICATION_POLICY,
          Array(payload["action_now"]).freeze,
          (payload["performance"] || {}).freeze
        )
      end

      private
        attr_reader :snapshot

        def build_cash_forecasts(payload)
          raw = payload.dig("forecast", "horizons") || {}
          WealthOs::DailyClose::ForecastBuilder::HORIZONS.to_h do |days|
            row = raw[days.to_s] || raw[days] || {}
            [ days, {
              "through_date" => row["through_date"],
              "income" => decimal(row["income"]),
              "liability_payments" => decimal(row["liability_payments"]),
              "net_cash" => decimal(row["net_cash"])
            }.freeze ]
          end
        end

        def sum_asset_rows(rows, types:)
          rows.select { |row|
            row["classification"] == "asset" && types.include?(row["accountable_type"])
          }.sum(BigDecimal("0")) { |row| decimal(row["reporting_value"]) }
        end

        def decimal(value)
          value.to_s.to_d
        end
    end
  end
end

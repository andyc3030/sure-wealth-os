# frozen_string_literal: true

module WealthOs
  module DailyClose
    class IncomeRiskBuilder
      STATE_RETENTION = {
        "forecast" => BigDecimal("0.70"),
        "accrued" => BigDecimal("0.90"),
        "declared" => BigDecimal("1.00")
      }.freeze

      CONFIDENCE_RETENTION = {
        "confirmed" => BigDecimal("1.00"),
        "high" => BigDecimal("0.90"),
        "estimated" => BigDecimal("0.75"),
        "low" => BigDecimal("0.50"),
        "unknown" => BigDecimal("0.00")
      }.freeze

      FUTURE_STATES = STATE_RETENTION.keys.freeze

      Result = Data.define(
        :baseline_income, :stressed_income, :income_at_risk, :sustainability_ratio,
        :scheduled_liabilities, :stressed_net_cash, :undated_income_count,
        :undated_income_amount, :top_source_share, :concentration_hhi,
        :events, :source_breakdown, :policy
      ) do
        def as_json(*)
          {
            "model" => "deterministic_income_stress",
            "statistical_var" => false,
            "baseline_income" => decimal_string(baseline_income),
            "stressed_income" => decimal_string(stressed_income),
            "income_at_risk" => decimal_string(income_at_risk),
            "sustainability_ratio" => decimal_string(sustainability_ratio),
            "scheduled_liabilities" => decimal_string(scheduled_liabilities),
            "stressed_net_cash" => decimal_string(stressed_net_cash),
            "undated_income_count" => undated_income_count,
            "undated_income_amount" => decimal_string(undated_income_amount),
            "top_source_share" => decimal_string(top_source_share),
            "concentration_hhi" => decimal_string(concentration_hhi),
            "events" => events,
            "source_breakdown" => source_breakdown,
            "policy" => policy
          }
        end

        private

          def decimal_string(value)
            value&.to_d&.to_s("F")
          end
      end

      def initialize(family:, close_date:, reporting_currency:, fx_resolver:, forecast:)
        @family = family
        @close_date = close_date.to_date
        @reporting_currency = reporting_currency
        @fx_resolver = fx_resolver
        @forecast = forecast
      end

      def call
        dated_rows = []
        undated_rows = []

        income_scope.find_each do |event|
          row = build_event_row(event)
          next unless row

          if row.fetch("due_date").nil?
            undated_rows << row
          elsif row.fetch("due_date") > close_date && row.fetch("due_date") <= horizon_date
            dated_rows << row
          end
        end

        baseline = sum_rows(dated_rows, "reporting_amount")
        stressed = sum_rows(dated_rows, "stressed_amount")
        at_risk = baseline - stressed
        liabilities = forecast.horizons.fetch(365).fetch("liability_payments").to_d
        source_breakdown = build_source_breakdown(dated_rows, baseline)

        Result.new(
          baseline,
          stressed,
          at_risk,
          ratio(stressed, baseline),
          liabilities,
          stressed - liabilities,
          undated_rows.size,
          sum_rows(undated_rows, "reporting_amount"),
          source_breakdown.first&.fetch("share")&.to_d,
          concentration_hhi(source_breakdown),
          dated_rows.map { |row| serialize_event_row(row) }.freeze,
          source_breakdown.map { |row| serialize_source_row(row) }.freeze,
          policy.freeze
        )
      end

      private

        attr_reader :family, :close_date, :reporting_currency, :fx_resolver, :forecast

        def horizon_date
          @horizon_date ||= close_date + 365.days
        end

        def income_scope
          IncomeEvent.where(family_id: family.id, state: FUTURE_STATES)
            .order(:canonical_key, :id)
        end

        def build_event_row(event)
          state_retention = STATE_RETENTION.fetch(event.state)
          confidence_retention = CONFIDENCE_RETENTION.fetch(event.confidence)
          effective_retention = state_retention * confidence_retention
          reporting_amount = convert(event.net_amount, event.currency)
          due = event.payable_on || event.expected_on || event.accrual_end_date

          {
            "income_event_id" => event.id,
            "canonical_key" => event.canonical_key,
            "income_type" => event.income_type,
            "state" => event.state,
            "confidence" => event.confidence,
            "due_date" => due,
            "source_key" => concentration_key(event),
            "native_currency" => event.currency,
            "native_net_amount" => event.net_amount.to_d,
            "reporting_currency" => reporting_currency,
            "reporting_amount" => reporting_amount,
            "state_retention" => state_retention,
            "confidence_retention" => confidence_retention,
            "effective_retention" => effective_retention,
            "stressed_amount" => reporting_amount * effective_retention,
            "at_risk_amount" => reporting_amount * (BigDecimal("1") - effective_retention)
          }
        end

        def concentration_key(event)
          return "security:#{event.security_id}" if event.security_id
          return "account:#{event.account_id}" if event.account_id
          return "source_system:#{event.source_system}" if event.source_system.present?

          "income_type:#{event.income_type}"
        end

        def build_source_breakdown(rows, baseline)
          rows.group_by { |row| row.fetch("source_key") }.map do |source_key, source_rows|
            amount = sum_rows(source_rows, "reporting_amount")
            stressed = sum_rows(source_rows, "stressed_amount")

            {
              "source_key" => source_key,
              "event_count" => source_rows.size,
              "amount" => amount,
              "stressed_amount" => stressed,
              "share" => ratio(amount, baseline)
            }
          end.sort_by { |row| [ -row.fetch("amount"), row.fetch("source_key") ] }
        end

        def concentration_hhi(source_rows)
          source_rows.sum(BigDecimal("0")) do |row|
            share = row.fetch("share")
            share ? share.to_d**2 : BigDecimal("0")
          end
        end

        def serialize_event_row(row)
          row.transform_values do |value|
            case value
            when BigDecimal then value.to_s("F")
            when Date then value.iso8601
            else value
            end
          end
        end

        def serialize_source_row(row)
          row.transform_values { |value| value.is_a?(BigDecimal) ? value.to_s("F") : value }
        end

        def policy
          {
            "horizon_days" => 365,
            "description" => "deterministic stress retention; not probabilistic VaR",
            "state_retention" => STATE_RETENTION.transform_values { |value| value.to_s("F") },
            "confidence_retention" => CONFIDENCE_RETENTION.transform_values { |value| value.to_s("F") },
            "undated_income" => "excluded_from_baseline_and_reported_separately",
            "fx_basis" => "authoritative close-date normalized FX"
          }
        end

        def sum_rows(rows, key)
          rows.sum(BigDecimal("0")) { |row| row.fetch(key).to_d }
        end

        def ratio(numerator, denominator)
          return nil if denominator.to_d.zero?

          numerator.to_d / denominator.to_d
        end

        def convert(amount, currency)
          fx_resolver.resolve(from: currency, to: reporting_currency, date: close_date).rate * amount.to_d
        end
    end
  end
end

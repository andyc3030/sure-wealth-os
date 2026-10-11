# frozen_string_literal: true

module WealthOs
  module DailyClose
    class ForecastBuilder
      HORIZONS = [ 7, 30, 90, 365 ].freeze

      Result = Data.define(:horizons, :undated_income_count) do
        def as_json(*)
          {
            "horizons" => horizons.transform_values do |row|
              row.transform_values { |value| value.is_a?(BigDecimal) ? value.to_s("F") : value }
            end,
            "undated_income_count" => undated_income_count
          }
        end
      end

      def initialize(family:, close_date:, reporting_currency:, fx_resolver:)
        @family = family
        @close_date = close_date.to_date
        @reporting_currency = reporting_currency
        @fx_resolver = fx_resolver
      end

      def call
        income_rows, undated_count = future_income_rows
        liability_rows = future_liability_rows

        horizons = HORIZONS.index_with do |days|
          horizon_date = close_date + days.days
          income = income_rows
            .select { |row| row.fetch(:date) <= horizon_date }
            .sum(BigDecimal("0")) { |row| row.fetch(:amount) }
          liabilities = liability_rows
            .select { |row| row.fetch(:date) <= horizon_date }
            .sum(BigDecimal("0")) { |row| row.fetch(:amount) }

          {
            "through_date" => horizon_date.iso8601,
            "income" => income,
            "liability_payments" => liabilities,
            "net_cash" => income - liabilities
          }
        end

        Result.new(horizons.freeze, undated_count)
      end

      private

        attr_reader :family, :close_date, :reporting_currency, :fx_resolver

        def future_income_rows
          rows = []
          undated = 0

          IncomeEvent.where(family_id: family.id, state: %w[forecast accrued declared]).find_each do |event|
            due_date = event.payable_on || event.expected_on || event.accrual_end_date
            if due_date.nil?
              undated += 1
              next
            end
            next unless due_date > close_date && due_date <= close_date + 365.days

            rows << { date: due_date, amount: convert(event.net_amount, event.currency) }
          end

          [ rows, undated ]
        end

        def future_liability_rows
          LiabilityPayment.where(
            family_id: family.id,
            payment_type: "scheduled",
            payment_date: (close_date + 1.day)..(close_date + 365.days)
          ).map do |payment|
            { date: payment.payment_date, amount: convert(payment.total_amount, payment.currency) }
          end
        end

        def convert(amount, currency)
          fx_resolver.resolve(from: currency, to: reporting_currency, date: close_date).rate * amount.to_d
        end
    end
  end
end

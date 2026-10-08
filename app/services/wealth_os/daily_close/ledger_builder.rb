# frozen_string_literal: true

module WealthOs
  module DailyClose
    class LedgerBuilder
      Result = Data.define(
        :income_by_state, :received_cash_today, :principal_paid_today,
        :financing_cost_today, :insurance_paid_today
      ) do
        def as_json(*)
          {
            "income_by_state" => income_by_state.transform_values { |value| value.to_s("F") },
            "received_cash_today" => received_cash_today.to_s("F"),
            "principal_paid_today" => principal_paid_today.to_s("F"),
            "financing_cost_today" => financing_cost_today.to_s("F"),
            "insurance_paid_today" => insurance_paid_today.to_s("F")
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
        income_by_state = IncomeEvent::STATES.index_with { BigDecimal("0") }
        received_cash_today = BigDecimal("0")

        IncomeEvent.where(family_id: family.id).find_each do |event|
          income_by_state[event.state] += convert(event.net_amount, event.currency)
          if event.received? && event.received_on == close_date
            received_cash_today += convert(event.received_cash, event.currency)
          end
        end

        actual_payments = LiabilityPayment.where(
          family_id: family.id,
          payment_type: "actual",
          payment_date: close_date
        )

        principal = BigDecimal("0")
        financing = BigDecimal("0")
        insurance = BigDecimal("0")

        actual_payments.find_each do |payment|
          principal += convert(payment.principal_amount, payment.currency)
          financing += convert(payment.financing_cost_amount, payment.currency)
          insurance += convert(payment.insurance_amount, payment.currency)
        end

        Result.new(income_by_state.freeze, received_cash_today, principal, financing, insurance)
      end

      private

        attr_reader :family, :close_date, :reporting_currency, :fx_resolver

        def convert(amount, currency)
          fx_resolver.resolve(from: currency, to: reporting_currency, date: close_date).rate * amount.to_d
        end
    end
  end
end

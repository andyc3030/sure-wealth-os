# frozen_string_literal: true

module WealthOs
  module Performance
    class Attribution
      Result = Data.define(
        :opening_value, :closing_value, :contributions, :withdrawals,
        :income, :tax_withheld, :fees, :financing_cost, :insurance_cost, :fx_effect, :capital_return,
        :explained_change, :unexplained_change
      )

      def self.call(opening_value:, closing_value:, capital_return:, contributions: 0, withdrawals: 0,
                    income: 0, tax_withheld: 0, fees: 0, financing_cost: 0, insurance_cost: 0, fx_effect: 0)
        values = {
          opening_value: opening_value,
          closing_value: closing_value,
          capital_return: capital_return,
          contributions: contributions,
          withdrawals: withdrawals,
          income: income,
          tax_withheld: tax_withheld,
          fees: fees,
          financing_cost: financing_cost,
          insurance_cost: insurance_cost,
          fx_effect: fx_effect
        }
        missing = values.select { |_name, value| value.nil? }.keys
        raise ArgumentError, "nil attribution components: #{missing.join(", ")}" if missing.any?

        decimal = ->(value) { value.to_d }
        opening = decimal.call(opening_value)
        closing = decimal.call(closing_value)
        contributions = decimal.call(contributions)
        withdrawals = decimal.call(withdrawals)
        income = decimal.call(income)
        tax = decimal.call(tax_withheld)
        fees = decimal.call(fees)
        financing = decimal.call(financing_cost)
        insurance = decimal.call(insurance_cost)
        fx = decimal.call(fx_effect)

        capital = decimal.call(capital_return)

        # Capital return is supplied by the deterministic valuation/performance
        # engine rather than manufactured as the balancing residual. That keeps
        # unexplained_change meaningful as a reconciliation/data-quality signal.
        explained = contributions - withdrawals + income - tax - fees - financing - insurance + fx + capital
        unexplained = (closing - opening) - explained

        Result.new(
          opening, closing, contributions, withdrawals,
          income, tax, fees, financing, insurance, fx, capital,
          explained, unexplained
        )
      end
    end
  end
end

# frozen_string_literal: true

module WealthOs
  module Performance
    class Attribution
      Result = Data.define(
        :opening_value, :closing_value, :contributions, :withdrawals,
        :income, :tax_withheld, :fees, :financing_cost, :fx_effect, :capital_return,
        :explained_change, :unexplained_change
      )

      def self.call(opening_value:, closing_value:, contributions: 0, withdrawals: 0,
                    income: 0, tax_withheld: 0, fees: 0, financing_cost: 0, fx_effect: 0)
        opening = opening_value.to_d
        closing = closing_value.to_d
        contributions = contributions.to_d
        withdrawals = withdrawals.to_d
        income = income.to_d
        tax = tax_withheld.to_d
        fees = fees.to_d
        financing = financing_cost.to_d
        fx = fx_effect.to_d

        # Closing = opening + external flows + economic return.
        economic_return = closing - opening - contributions + withdrawals
        capital = economic_return - income + tax + fees + financing - fx

        explained = contributions - withdrawals + income - tax - fees - financing + fx + capital
        unexplained = (closing - opening) - explained

        Result.new(
          opening, closing, contributions, withdrawals,
          income, tax, fees, financing, fx, capital,
          explained, unexplained
        )
      end
    end
  end
end

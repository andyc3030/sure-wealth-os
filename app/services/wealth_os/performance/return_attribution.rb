# frozen_string_literal: true

module WealthOs
  module Performance
    class ReturnAttribution
      Result = Data.define(
        :opening_value,
        :closing_value,
        :contributions,
        :withdrawals,
        :total_return_amount,
        :capital_effect,
        :income_effect,
        :fx_effect,
        :fee_effect,
        :financing_effect,
        :total_return_rate
      ) do
        def explained_return
          capital_effect + income_effect + fx_effect + fee_effect + financing_effect
        end
      end

      def self.call(opening_value:, closing_value:, contributions: 0, withdrawals: 0,
                    income: 0, fees: 0, financing_costs: 0, fx_effect: 0)
        opening = opening_value.to_d
        closing = closing_value.to_d
        contributions = contributions.to_d
        withdrawals = withdrawals.to_d
        income_effect = income.to_d
        fx_effect = fx_effect.to_d
        fee_effect = -fees.to_d
        financing_effect = -financing_costs.to_d

        raise ArgumentError, "contributions and withdrawals must be non-negative" if contributions.negative? || withdrawals.negative?
        raise ArgumentError, "fees and financing costs must be non-negative" if fees.to_d.negative? || financing_costs.to_d.negative?

        total_return = closing - opening - contributions + withdrawals
        capital_effect = total_return - income_effect - fx_effect - fee_effect - financing_effect
        rate = opening.zero? ? nil : total_return / opening

        Result.new(
          opening,
          closing,
          contributions,
          withdrawals,
          total_return,
          capital_effect,
          income_effect,
          fx_effect,
          fee_effect,
          financing_effect,
          rate
        )
      end
    end
  end
end

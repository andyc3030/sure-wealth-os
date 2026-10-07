# frozen_string_literal: true

module WealthOs
  module Accounting
    class NetWorthBridge
      Result = Data.define(:opening_net_worth, :closing_net_worth, :expected_closing_net_worth,
                           :unexplained_change, :economic_effects, :financing_flows)

      def self.call(**attributes)
        new(**attributes).call
      end

      def initialize(opening_net_worth:, closing_net_worth:, external_contributions: 0, external_withdrawals: 0,
                     capital_pnl: 0, income: 0, fx_effect: 0, fees: 0, financing_cost: 0,
                     property_private_revaluation: 0, corrections: 0, debt_drawdowns: 0,
                     debt_principal_repayments: 0)
        @values = {
          opening_net_worth: opening_net_worth,
          closing_net_worth: closing_net_worth,
          external_contributions: external_contributions,
          external_withdrawals: external_withdrawals,
          capital_pnl: capital_pnl,
          income: income,
          fx_effect: fx_effect,
          fees: fees,
          financing_cost: financing_cost,
          property_private_revaluation: property_private_revaluation,
          corrections: corrections,
          debt_drawdowns: debt_drawdowns,
          debt_principal_repayments: debt_principal_repayments
        }.transform_values(&:to_d)
      end

      def call
        effects = {
          external_contributions: @values[:external_contributions],
          external_withdrawals: -@values[:external_withdrawals],
          capital_pnl: @values[:capital_pnl],
          income: @values[:income],
          fx_effect: @values[:fx_effect],
          fees: -@values[:fees],
          financing_cost: -@values[:financing_cost],
          property_private_revaluation: @values[:property_private_revaluation],
          corrections: @values[:corrections]
        }

        expected = @values[:opening_net_worth] + effects.values.sum(BigDecimal("0"))
        unexplained = @values[:closing_net_worth] - expected

        Result.new(
          opening_net_worth: @values[:opening_net_worth],
          closing_net_worth: @values[:closing_net_worth],
          expected_closing_net_worth: expected,
          unexplained_change: unexplained,
          economic_effects: effects,
          financing_flows: {
            debt_drawdowns: @values[:debt_drawdowns],
            debt_principal_repayments: @values[:debt_principal_repayments],
            net_worth_effect: BigDecimal("0"),
            explanation: "Debt principal drawdown/repayment moves cash and liability together; financing cost is attributed separately."
          }
        )
      end
    end
  end
end

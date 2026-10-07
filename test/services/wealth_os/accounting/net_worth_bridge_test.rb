require "test_helper"

class WealthOs::Accounting::NetWorthBridgeTest < ActiveSupport::TestCase
  test "attributes economic change while principal financing movements are net-worth neutral" do
    result = WealthOs::Accounting::NetWorthBridge.call(
      opening_net_worth: 1000,
      closing_net_worth: 1110,
      external_contributions: 100,
      external_withdrawals: 50,
      capital_pnl: 40,
      income: 20,
      fx_effect: 10,
      fees: 5,
      financing_cost: 10,
      property_private_revaluation: 5,
      corrections: 0,
      debt_drawdowns: 500,
      debt_principal_repayments: 100
    )

    assert_equal BigDecimal("1110"), result.expected_closing_net_worth
    assert_equal BigDecimal("0"), result.unexplained_change
    assert_equal BigDecimal("0"), result.financing_flows[:net_worth_effect]
    assert_equal BigDecimal("500"), result.financing_flows[:debt_drawdowns]
    assert_equal BigDecimal("100"), result.financing_flows[:debt_principal_repayments]
    assert_equal BigDecimal("-10"), result.economic_effects[:financing_cost]
  end

  test "reports unexplained residual rather than forcing reconciliation" do
    result = WealthOs::Accounting::NetWorthBridge.call(
      opening_net_worth: 1000,
      closing_net_worth: 1015,
      capital_pnl: 10
    )

    assert_equal BigDecimal("1010"), result.expected_closing_net_worth
    assert_equal BigDecimal("5"), result.unexplained_change
  end
end

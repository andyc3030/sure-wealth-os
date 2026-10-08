require "test_helper"

class WealthOs::Performance::NetWorthAttributionTest < ActiveSupport::TestCase
  test "principal repayment is net-worth neutral while financing cost reduces wealth" do
    result = WealthOs::Performance::NetWorthAttribution.call(
      opening_net_worth: 100_000,
      closing_net_worth: 99_250,
      components: {
        cash_principal_payment: -1250,
        liability_principal_reduction: 1250,
        financing_cost: -750
      },
      tolerance: 0
    )

    assert_equal BigDecimal("-750"), result.actual_change
    assert_equal BigDecimal("-750"), result.explained_change
    assert_equal 0, result.residual
    assert result.reconciled?
  end

  test "exposes unexplained residual rather than forcing attribution" do
    result = WealthOs::Performance::NetWorthAttribution.call(
      opening_net_worth: 1000,
      closing_net_worth: 1100,
      components: { market: 90 },
      tolerance: 1
    )

    assert_equal BigDecimal("10"), result.residual
    assert_not result.reconciled?
  end
end

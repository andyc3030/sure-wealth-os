require "test_helper"

class WealthOs::Performance::AttributionTest < ActiveSupport::TestCase
  test "bridges opening value to closing value without mixing contributions with return" do
    result = WealthOs::Performance::Attribution.call(
      opening_value: 1000,
      closing_value: 1200,
      contributions: 100,
      withdrawals: 50,
      income: 40,
      fees: 10,
      financing_cost: 20,
      fx_effect: 10
    )

    assert_equal BigDecimal("130"), result.capital_return
    assert_equal BigDecimal("200"), result.explained_change
    assert_equal BigDecimal("0"), result.unexplained_change
  end
end

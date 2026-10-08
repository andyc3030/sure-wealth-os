require "test_helper"

class WealthOs::Performance::ReturnAttributionTest < ActiveSupport::TestCase
  test "separates capital income FX fees and financing effects" do
    result = WealthOs::Performance::ReturnAttribution.call(
      opening_value: 1000,
      closing_value: 1180,
      contributions: 100,
      withdrawals: 0,
      income: 40,
      fees: 5,
      financing_costs: 10,
      fx_effect: 20
    )

    # Total investment return = 1180 - 1000 - 100 = 80.
    assert_equal BigDecimal("80"), result.total_return_amount
    assert_equal BigDecimal("-5"), result.fee_effect
    assert_equal BigDecimal("-10"), result.financing_effect
    assert_equal BigDecimal("35"), result.capital_effect
    assert_equal result.total_return_amount, result.explained_return
    assert_in_delta 0.08, result.total_return_rate.to_f, 1e-12
  end
end

require "test_helper"

class WealthOs::Performance::FxAttributionTest < ActiveSupport::TestCase
  test "local and FX effects exactly bridge reporting-currency change" do
    result = WealthOs::Performance::FxAttribution.call(
      opening_local: 100,
      closing_local: 110,
      opening_fx: 1.20,
      closing_fx: 1.25
    )

    assert_equal BigDecimal("120"), result.opening_reporting_value
    assert_equal BigDecimal("137.5"), result.closing_reporting_value
    assert_equal BigDecimal("12"), result.local_market_effect
    assert_equal BigDecimal("5.5"), result.fx_effect
    assert_equal BigDecimal("17.5"), result.total_change
    assert_equal result.total_change, result.local_market_effect + result.fx_effect
  end
end

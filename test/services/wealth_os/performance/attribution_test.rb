require "test_helper"

class WealthOs::Performance::AttributionTest < ActiveSupport::TestCase
  test "bridges opening value to closing value without mixing contributions with return" do
    result = WealthOs::Performance::Attribution.call(
      opening_value: 1000,
      closing_value: 1200,
      capital_return: 135,
      contributions: 100,
      withdrawals: 50,
      income: 40,
      tax_withheld: 5,
      fees: 10,
      financing_cost: 20,
      insurance_cost: 15,
      fx_effect: 10
    )

    assert_equal BigDecimal("135"), result.capital_return
    assert_equal BigDecimal("5"), result.tax_withheld
    assert_equal BigDecimal("15"), result.insurance_cost
    assert_equal BigDecimal("200"), result.explained_change
    assert_equal BigDecimal("0"), result.unexplained_change
  end
  test "retains unexplained change when supplied attribution does not bridge" do
    result = WealthOs::Performance::Attribution.call(
      opening_value: 1000,
      closing_value: 1200,
      capital_return: 130,
      contributions: 100,
      withdrawals: 50,
      income: 40,
      tax_withheld: 5,
      fees: 10,
      financing_cost: 20,
      insurance_cost: 15,
      fx_effect: 10
    )

    assert_equal BigDecimal("130"), result.capital_return
    assert_equal BigDecimal("180"), result.explained_change
    assert_equal BigDecimal("20"), result.unexplained_change
  end
end

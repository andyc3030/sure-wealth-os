require "test_helper"

class WealthOs::CorporateActions::SplitAdjustmentTest < ActiveSupport::TestCase
  test "two for one doubles quantity and halves per-unit basis without changing total basis" do
    result = WealthOs::CorporateActions::SplitAdjustment.call(
      quantity: 10,
      cost_basis_per_unit: 100,
      numerator: 2,
      denominator: 1
    )

    assert_equal BigDecimal("20"), result.quantity
    assert_equal BigDecimal("50"), result.cost_basis_per_unit
    assert_equal BigDecimal("1000"), result.total_cost_basis
  end

  test "one for four reverse split divides quantity and multiplies per-unit basis" do
    result = WealthOs::CorporateActions::SplitAdjustment.call(
      quantity: 20,
      cost_basis_per_unit: 25,
      numerator: 1,
      denominator: 4
    )

    assert_equal BigDecimal("5"), result.quantity
    assert_equal BigDecimal("100"), result.cost_basis_per_unit
    assert_equal BigDecimal("500"), result.total_cost_basis
  end
end

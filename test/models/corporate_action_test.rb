require "test_helper"

class CorporateActionTest < ActiveSupport::TestCase
  test "split actions require a positive ratio" do
    action = CorporateAction.new(
      family: families(:dylan_family),
      security: securities(:aapl),
      canonical_key: "aapl-split",
      action_type: "split",
      effective_date: Date.current
    )

    assert_not action.valid?
    assert_includes action.errors[:base], "split actions require numerator and denominator"
  end

  test "split adjustment preserves total cost" do
    action = CorporateAction.create!(
      family: families(:dylan_family),
      security: securities(:aapl),
      canonical_key: "aapl-4-for-1",
      action_type: "split",
      effective_date: Date.current,
      ratio_numerator: 4,
      ratio_denominator: 1
    )

    result = WealthOs::CorporateActions::SplitAdjustment.for_action(
      action,
      quantity: 10,
      unit_cost: 200
    )

    assert_equal BigDecimal("40"), result.quantity
    assert_equal BigDecimal("50"), result.unit_cost
    assert_equal BigDecimal("2000"), result.total_cost
  end

  test "reverse split preserves total cost for fractional quantity" do
    result = WealthOs::CorporateActions::SplitAdjustment.call(
      quantity: 15,
      unit_cost: 20,
      numerator: 1,
      denominator: 3
    )

    assert_equal BigDecimal("5"), result.quantity
    assert_equal BigDecimal("60"), result.unit_cost
    assert_equal BigDecimal("300"), result.total_cost
  end
end

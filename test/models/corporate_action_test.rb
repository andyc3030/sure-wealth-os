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
  test "observed action becomes position-affecting only after validated transition" do
    action = CorporateAction.create!(
      family: families(:dylan_family),
      security: securities(:aapl),
      canonical_key: "aapl-audited-split",
      action_type: "split",
      status: "observed",
      effective_date: Date.current,
      ratio_numerator: 2,
      ratio_denominator: 1
    )

    assert_equal 1, action.transitions.count
    assert_not_includes CorporateAction.position_affecting, action

    action.transition_to!("validated", reason: "issuer source verified")

    assert_equal "validated", action.status
    assert_equal 2, action.transitions.count
    assert_includes CorporateAction.position_affecting, action
    assert_not action.update(ratio_numerator: 3)
    assert_includes action.errors[:base], "corporate actions must be changed through transition_to!"
  end

  test "corporate action status cannot move backwards" do
    action = CorporateAction.create!(
      family: families(:dylan_family),
      security: securities(:aapl),
      canonical_key: "aapl-applied-split",
      action_type: "split",
      status: "validated",
      effective_date: Date.current,
      ratio_numerator: 2,
      ratio_denominator: 1
    )
    action.transition_to!("applied")

    assert_raises(ArgumentError) { action.transition_to!("validated") }
  end

end

require "test_helper"

class CorporateActionTest < ActiveSupport::TestCase
  test "split exposes an exact ratio" do
    action = CorporateAction.create!(
      family: families(:empty),
      security: Security.create!(ticker: "SPLT", name: "Split Co"),
      action_type: "stock_split",
      status: "confirmed",
      effective_date: Date.current,
      ratio_numerator: 2,
      ratio_denominator: 1
    )

    assert action.split?
    assert_equal BigDecimal("2"), action.ratio
  end

  test "split requires positive ratio" do
    action = CorporateAction.new(
      family: families(:empty),
      security: Security.create!(ticker: "BAD", name: "Bad Split"),
      action_type: "stock_split",
      status: "confirmed",
      effective_date: Date.current
    )

    assert_not action.valid?
    assert_includes action.errors[:base], "split actions require a positive numerator and denominator"
  end
  test "new corporate actions default to pending and are not position affecting" do
    action = CorporateAction.create!(
      family: families(:empty),
      security: Security.create!(ticker: "PEND", name: "Pending Split"),
      action_type: "stock_split",
      effective_date: Date.current,
      ratio_numerator: 2,
      ratio_denominator: 1
    )

    assert_equal "pending", action.status
    assert_not_includes CorporateAction.position_affecting, action
  end

  test "confirmed corporate actions are immutable" do
    action = CorporateAction.create!(
      family: families(:empty),
      security: Security.create!(ticker: "IMM", name: "Immutable Split"),
      action_type: "stock_split",
      status: "confirmed",
      effective_date: Date.current,
      ratio_numerator: 2,
      ratio_denominator: 1
    )

    assert_not action.update(ratio_numerator: 3)
    assert_includes action.errors[:base], "confirmed corporate actions are immutable"
    assert_not action.destroy
    assert CorporateAction.exists?(action.id)
  end
end

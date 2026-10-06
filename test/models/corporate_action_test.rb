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
end

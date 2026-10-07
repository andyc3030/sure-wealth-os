require "test_helper"

class CorporateActionTest < ActiveSupport::TestCase
  test "split adjustment preserves total cost basis" do
    result = CorporateAction::SplitAdjustment.call(
      quantity: 10,
      unit_cost: 100,
      numerator: 2,
      denominator: 1
    )

    assert_equal BigDecimal("20"), result.quantity
    assert_equal BigDecimal("50"), result.unit_cost
    assert_equal BigDecimal("1000"), result.total_cost
  end

  test "deterministic split processor changes units and unit cost only" do
    action = CorporateAction.create!(
      family: families(:dylan_family),
      security: securities(:aapl),
      action_key: "AAPL-split-test",
      action_type: "split",
      status: "effective",
      processing_mode: "deterministic",
      effective_date: Date.current,
      ratio_numerator: 4,
      ratio_denominator: 1
    )

    result = WealthOs::Accounting::CorporateActionProcessor.call(
      action: action,
      quantity: 5,
      unit_cost: 200
    )

    assert_equal BigDecimal("20"), result.quantity
    assert_equal BigDecimal("50"), result.unit_cost
    assert_equal securities(:aapl), result.security
    assert_equal "1000.0", result.notes["total_cost_preserved"]
  end

  test "unsupported corporate action fails to manual review instead of guessing" do
    action = CorporateAction.create!(
      family: families(:dylan_family),
      security: securities(:aapl),
      action_key: "AAPL-merger-test",
      action_type: "merger",
      status: "announced",
      processing_mode: "manual_review",
      effective_date: 1.month.from_now.to_date
    )

    assert_raises(WealthOs::Accounting::CorporateActionProcessor::ManualReviewRequired) do
      WealthOs::Accounting::CorporateActionProcessor.call(
        action: action,
        quantity: 10,
        unit_cost: 100
      )
    end
  end

  test "unsupported type cannot be mislabeled deterministic" do
    action = CorporateAction.new(
      family: families(:dylan_family),
      security: securities(:aapl),
      action_key: "AAPL-roc-test",
      action_type: "return_of_capital",
      status: "effective",
      processing_mode: "deterministic",
      effective_date: Date.current,
      cash_per_unit: 1,
      currency: "USD"
    )

    assert_not action.valid?
    assert_includes action.errors[:processing_mode], "is not supported deterministically for return_of_capital; manual review is required"
  end
end

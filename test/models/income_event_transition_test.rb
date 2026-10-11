require "test_helper"

class IncomeEventTransitionTest < ActiveSupport::TestCase
  test "transition history is append-only" do
    event = IncomeEvent.create!(
      family: families(:dylan_family),
      canonical_key: "append-only-income",
      state: "forecast",
      income_type: "dividend",
      gross_amount: 10,
      currency: "USD"
    )
    transition = event.transitions.first

    assert_not transition.update(reason: "rewrite history")
    assert_includes transition.errors[:base], "income event transitions are append-only"
    assert_not transition.destroy
    assert IncomeEventTransition.exists?(transition.id)
  end
end

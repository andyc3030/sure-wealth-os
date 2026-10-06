require "test_helper"

class IncomeEventTest < ActiveSupport::TestCase
  test "forecast transitions to declared then received without double counting" do
    family = families(:empty)

    forecast = IncomeEvent.create!(
      family: family,
      event_key: "dividend:abc",
      income_type: "dividend",
      state: "forecast",
      amount: 100,
      currency: "USD",
      effective_date: Date.current + 30,
      confidence: "estimated"
    )

    declared = forecast.transition_to!(
      "declared",
      amount: 95,
      declared_on: Date.current,
      payable_on: Date.current + 14,
      confidence: "confirmed"
    )

    received = declared.transition_to!(
      "received",
      amount: 95,
      cash_amount: 85,
      tax_withheld: 10,
      effective_date: Date.current + 14,
      payable_on: Date.current + 14
    )

    current = IncomeEvent.current.where(family: family, event_key: "dividend:abc").to_a

    assert_equal [ received.id ], current.map(&:id)
    assert_equal "received", current.first.state
    assert_equal BigDecimal("85"), current.first.received_cash

    summary = WealthOs::Income::LifecycleSummary.new(IncomeEvent.where(family: family)).call
    assert_equal BigDecimal("95"), summary["USD"]["received"]
    assert_equal BigDecimal("85"), summary["USD"]["received_cash"]
    assert_equal BigDecimal("0"), summary["USD"]["forecast"]
    assert_equal BigDecimal("0"), summary["USD"]["declared"]
  end

  test "received state cannot move backwards" do
    event = IncomeEvent.create!(
      family: families(:empty),
      event_key: "interest:1",
      income_type: "interest",
      state: "received",
      amount: 10,
      cash_amount: 10,
      currency: "USD",
      effective_date: Date.current
    )

    invalid = event.transition_to!("forecast", amount: 11)
    flunk "transition should have failed, got #{invalid.inspect}"
  rescue ActiveRecord::RecordInvalid => error
    assert_includes error.record.errors[:state], "cannot transition from received to forecast"
  end

  test "versions are immutable" do
    event = IncomeEvent.create!(
      family: families(:empty),
      event_key: "coupon:1",
      income_type: "coupon",
      state: "accrued",
      amount: 25,
      currency: "USD",
      effective_date: Date.current
    )

    assert_not event.update(amount: 30)
    assert_includes event.errors[:base], "income event versions are immutable; create a successor"
    assert_not event.destroy
    assert IncomeEvent.exists?(event.id)
  end
end

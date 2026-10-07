require "test_helper"

class IncomeEventTest < ActiveSupport::TestCase
  test "forecast to declared to received has exactly one current version" do
    family = families(:dylan_family)

    forecast = IncomeEvent.create!(
      family: family,
      event_key: "AAPL:2026-Q4-dividend",
      income_type: "dividend",
      state: "forecast",
      gross_amount: 100,
      currency: "USD",
      expected_date: Date.new(2026, 11, 15),
      forecast_method: "historical_rate",
      confidence: 0.7
    )

    declared = forecast.transition_to!(
      "declared",
      gross_amount: 105,
      declaration_date: Date.new(2026, 10, 25),
      payment_date: Date.new(2026, 11, 15),
      amount_per_unit: 0.25,
      units_entitled: 420
    )

    received = declared.transition_to!(
      "received",
      gross_amount: 105,
      withholding_tax_amount: 15,
      fee_amount: 1,
      received_at: Time.zone.parse("2026-11-15 14:00:00")
    )

    assert_equal 3, IncomeEvent.where(family: family, event_key: forecast.event_key).count
    assert_equal [ received.id ], IncomeEvent.where(family: family, event_key: forecast.event_key).current_versions.pluck(:id)
    assert_equal BigDecimal("89"), received.net_amount
    assert forecast.reload.successor.present?
    assert declared.reload.successor.present?
    assert received.current_version?
  end

  test "ordinary dividend cannot be accrued before declaration" do
    event = IncomeEvent.new(
      family: families(:dylan_family),
      event_key: "undeclared-dividend",
      income_type: "dividend",
      state: "accrued",
      gross_amount: 10,
      currency: "USD",
      accrual_end_date: Date.current
    )

    assert_not event.valid?
    assert_includes event.errors[:declaration_date], "is required before equity/fund distributions can be treated as accrued"
  end

  test "interest may accrue without declaration" do
    event = IncomeEvent.new(
      family: families(:dylan_family),
      event_key: "deposit-interest-2026-10",
      income_type: "interest",
      state: "accrued",
      gross_amount: 12.50,
      currency: "GBP",
      accrual_start_date: Date.new(2026, 10, 1),
      accrual_end_date: Date.new(2026, 10, 31)
    )

    assert event.valid?
  end

  test "summary counts only current event versions and preserves currency" do
    family = families(:dylan_family)

    first = IncomeEvent.create!(
      family: family,
      event_key: "coupon-1",
      income_type: "coupon",
      state: "forecast",
      gross_amount: 50,
      currency: "GBP",
      expected_date: 1.month.from_now.to_date
    )
    first.transition_to!(
      "received",
      received_at: Time.current,
      gross_amount: 50,
      withholding_tax_amount: 5
    )

    IncomeEvent.create!(
      family: family,
      event_key: "coupon-2",
      income_type: "coupon",
      state: "forecast",
      gross_amount: 25,
      currency: "USD",
      expected_date: 2.months.from_now.to_date
    )

    summary = IncomeEvent::Summary.new(IncomeEvent.where(family: family))

    gbp_received = summary.for(state: :received, currency: "GBP")
    usd_forecast = summary.for(state: :forecast, currency: "USD")

    assert_equal BigDecimal("50"), gbp_received.gross_amount
    assert_equal BigDecimal("45"), gbp_received.net_amount
    assert_equal 1, gbp_received.event_count
    assert_equal BigDecimal("25"), usd_forecast.gross_amount
    assert_nil summary.for(state: :forecast, currency: "GBP"), "superseded forecast must not be double counted"
  end

  test "invalid state transition fails rather than rewriting history" do
    received = IncomeEvent.create!(
      family: families(:dylan_family),
      event_key: "already-received",
      income_type: "interest",
      state: "received",
      gross_amount: 10,
      currency: "GBP",
      received_at: Time.current
    )

    assert_raises(ArgumentError) { received.transition_to!("forecast") }
    assert_not received.update(gross_amount: 20)
  end
end

require "test_helper"

class IncomeEventTest < ActiveSupport::TestCase
  setup do
    @family = families(:dylan_family)
    @account = accounts(:investment)
  end

  test "forecast progresses to declared and received without duplicate current states" do
    event = IncomeEvent.create!(
      family: @family,
      account: @account,
      security: securities(:aapl),
      canonical_key: "aapl-dividend-2026-q4",
      state: "forecast",
      income_type: "dividend",
      gross_amount: 100,
      currency: "USD",
      expected_on: Date.new(2026, 12, 15),
      confidence: "estimated"
    )

    assert_equal 1, event.transitions.count
    assert_equal "forecast", event.transitions.first.to_state

    event.transition_to!(
      "declared",
      attributes: {
        gross_amount: 105,
        declared_on: Date.new(2026, 11, 1),
        payable_on: Date.new(2026, 12, 15),
        confidence: "confirmed"
      },
      reason: "issuer declaration"
    )

    assert_equal "declared", event.state
    assert_equal BigDecimal("105"), event.gross_amount
    assert_equal 2, event.transitions.count

    event.transition_to!(
      "received",
      attributes: {
        withholding_tax_amount: 15,
        received_on: Date.new(2026, 12, 15)
      },
      reason: "broker cash receipt"
    )

    assert_equal "received", event.state
    assert_equal BigDecimal("90"), event.net_amount
    assert_equal 3, event.transitions.count

    summary = WealthOs::Income::StateSummary.call([ event ]).fetch("USD")
    assert_equal 0, summary.forecast
    assert_equal 0, summary.declared
    assert_equal BigDecimal("90"), summary.received
  end

  test "accrued income requires an explicit accrual interval" do
    event = IncomeEvent.new(
      family: @family,
      canonical_key: "bond-accrual",
      state: "accrued",
      income_type: "coupon",
      gross_amount: 25,
      currency: "USD"
    )

    assert_not event.valid?
    assert_includes event.errors[:base], "accrued income requires accrual start and end dates"
  end

  test "ordinary direct updates are blocked and revisions must use transition helper" do
    event = IncomeEvent.create!(
      family: @family,
      canonical_key: "interest-forecast",
      state: "forecast",
      income_type: "interest",
      gross_amount: 10,
      currency: "USD"
    )

    assert_not event.update(gross_amount: 20)
    assert_includes event.errors[:base], "income events must be changed through transition_to!"

    event.transition_to!("forecast", attributes: { gross_amount: 20 }, reason: "forecast revision")
    assert_equal BigDecimal("20"), event.reload.gross_amount
    assert_equal 2, event.transitions.count
  end

  test "received income requires receipt date and cannot transition backwards" do
    event = IncomeEvent.create!(
      family: @family,
      canonical_key: "cash-interest",
      state: "forecast",
      income_type: "interest",
      gross_amount: 5,
      currency: "USD"
    )

    assert_raises(ActiveRecord::RecordInvalid) do
      event.transition_to!("received")
    end

    event.reload.transition_to!("received", attributes: { received_on: Date.current })
    assert_raises(ArgumentError) { event.transition_to!("declared", attributes: { declared_on: Date.current }) }
  end

  test "state summary keeps currencies separate instead of silently converting" do
    usd = IncomeEvent.create!(
      family: @family, canonical_key: "usd-income", state: "forecast",
      income_type: "interest", gross_amount: 10, currency: "USD"
    )
    gbp = IncomeEvent.create!(
      family: @family, canonical_key: "gbp-income", state: "forecast",
      income_type: "interest", gross_amount: 8, currency: "GBP"
    )

    result = WealthOs::Income::StateSummary.call([ usd, gbp ])

    assert_equal %w[GBP USD], result.keys.sort
    assert_equal BigDecimal("10"), result["USD"].forecast
    assert_equal BigDecimal("8"), result["GBP"].forecast
  end
end

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
      payable_on: Date.current + 14,
      raw_source_record: income_evidence(family, "dividend-received")
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
      effective_date: Date.current,
      raw_source_record: income_evidence(families(:empty), "received-backwards")
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
  test "only one lifecycle root is allowed per family and event key" do
    family = families(:empty)

    IncomeEvent.create!(
      family: family,
      event_key: "dividend:unique",
      income_type: "dividend",
      state: "forecast",
      amount: 10,
      currency: "USD",
      effective_date: Date.current
    )

    duplicate = IncomeEvent.new(
      family: family,
      event_key: "dividend:unique",
      income_type: "dividend",
      state: "forecast",
      amount: 10,
      currency: "USD",
      effective_date: Date.current
    )

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:event_key], "already has a lifecycle root"
  end

  test "rejects raw source lineage from another family" do
    raw = RawSourceRecord.ingest!(
      family: families(:dylan_family),
      source_system: "manual",
      record_type: "income",
      source_key: "foreign-income",
      payload: { "amount" => "10" }
    )

    event = IncomeEvent.new(
      family: families(:empty),
      raw_source_record: raw,
      event_key: "interest:foreign",
      income_type: "interest",
      state: "received",
      amount: 10,
      currency: "USD",
      effective_date: Date.current
    )

    assert_not event.valid?
    assert_includes event.errors[:raw_source_record], "must belong to the same family"
  end
  test "ordinary dividend income cannot be accrued before declaration" do
    event = IncomeEvent.new(
      family: families(:empty),
      event_key: "dividend:no-accrual",
      income_type: "dividend",
      state: "accrued",
      amount: 5,
      currency: "USD",
      effective_date: Date.current
    )

    assert_not event.valid?
    assert_includes event.errors[:state], "dividend income must remain forecast until it is declared or received"
  end
  test "transition cannot override lifecycle identity or state" do
    event = IncomeEvent.create!(
      family: families(:empty),
      event_key: "interest:locked",
      income_type: "interest",
      state: "forecast",
      amount: 10,
      currency: "USD",
      effective_date: Date.current
    )

    assert_raises(ArgumentError) do
      event.transition_to!("received", event_key: "different", amount: 10)
    end

    assert_raises(ArgumentError) do
      event.transition_to!("received", state: "forecast", amount: 10)
    end
  end

  test "received cash must reconcile to gross less withholding and fees" do
    event = IncomeEvent.new(
      family: families(:empty),
      event_key: "dividend:cash-reconcile",
      income_type: "dividend",
      state: "received",
      amount: 100,
      cash_amount: 80,
      tax_withheld: 10,
      fees: 5,
      currency: "USD",
      effective_date: Date.current
    )

    assert_not event.valid?
    assert_includes event.errors[:cash_amount], "must equal gross income minus withholding tax and fees"
  end

  test "cash amount is not permitted before received state" do
    event = IncomeEvent.new(
      family: families(:empty),
      event_key: "interest:no-cash-before-received",
      income_type: "interest",
      state: "declared",
      amount: 10,
      cash_amount: 10,
      currency: "USD",
      effective_date: Date.current
    )

    assert_not event.valid?
    assert_includes event.errors[:cash_amount], "can only be recorded for received income"
  end

  test "generic other income cannot be accrued without a defined accrual rule" do
    event = IncomeEvent.new(
      family: families(:empty),
      event_key: "other:no-accrual",
      income_type: "other",
      state: "accrued",
      amount: 10,
      currency: "USD",
      effective_date: Date.current
    )

    assert_not event.valid?
    assert_includes event.errors[:state], "other income must remain forecast until it is declared or received"
  end

  test "received income requires a booked entry or raw source record" do
    event = IncomeEvent.new(
      family: families(:empty),
      event_key: "interest:no-evidence",
      income_type: "interest",
      state: "received",
      amount: 10,
      cash_amount: 10,
      currency: "USD",
      effective_date: Date.current
    )

    assert_not event.valid?
    assert_includes event.errors[:base], "received income requires a booked entry or raw source record"
  end

  test "received cash may be known while gross income and deductions remain unknown" do
    family = families(:empty)
    evidence = income_evidence(family, "cash-only-received")

    event = IncomeEvent.create!(
      family: family,
      raw_source_record: evidence,
      event_key: "interest:cash-only",
      income_type: "interest",
      state: "received",
      amount: nil,
      cash_amount: 85,
      tax_withheld: nil,
      fees: nil,
      currency: "USD",
      effective_date: Date.current
    )

    summary = WealthOs::Income::LifecycleSummary.new(IncomeEvent.where(family: family)).call

    assert_nil event.amount
    assert_equal BigDecimal("85"), event.received_cash
    assert_equal BigDecimal("0"), summary["USD"]["received"]
    assert_equal BigDecimal("85"), summary["USD"]["received_cash"]
    assert_equal BigDecimal("85"), summary["USD"]["received_gross_unknown_cash"]
  end

  test "known gross and complete deductions must reconcile to received cash" do
    family = families(:empty)
    event = IncomeEvent.create!(
      family: family,
      raw_source_record: income_evidence(family, "gross-reconciled"),
      event_key: "dividend:gross-reconciled",
      income_type: "dividend",
      state: "received",
      amount: 100,
      cash_amount: 85,
      tax_withheld: 10,
      fees: 5,
      currency: "USD",
      effective_date: Date.current
    )

    assert_equal BigDecimal("85"), event.received_cash
  end

  private

    def income_evidence(family, key)
      RawSourceRecord.ingest!(
        family: family,
        source_system: "test_income_source",
        record_type: "income",
        source_key: key,
        payload: { "verified" => true }
      )
    end

end

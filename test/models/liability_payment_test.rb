require "test_helper"

class LiabilityPaymentTest < ActiveSupport::TestCase
  test "principal is separate from financing cost" do
    payment = LiabilityPayment.create!(
      family: families(:dylan_family),
      account: accounts(:loan),
      canonical_key: "mortgage-payment-2026-10",
      payment_date: Date.new(2026, 10, 1),
      payment_type: "actual",
      total_amount: 2000,
      principal_amount: 1250,
      interest_amount: 700,
      fee_amount: 50,
      insurance_amount: 0,
      currency: "USD"
    )

    assert_equal BigDecimal("750"), payment.financing_cost_amount
    assert_equal BigDecimal("750"), payment.non_principal_cost_amount
    assert_equal BigDecimal("1250"), payment.principal_amount
  end

  test "components must equal total" do
    payment = LiabilityPayment.new(
      family: families(:dylan_family),
      account: accounts(:loan),
      canonical_key: "invalid-payment",
      payment_date: Date.current,
      payment_type: "actual",
      total_amount: 2000,
      principal_amount: 1250,
      interest_amount: 600,
      fee_amount: 50,
      currency: "USD"
    )

    assert_not payment.valid?
    assert_includes payment.errors[:total_amount], "must equal principal + interest + fees + insurance"
  end

  test "can reuse the existing loan schedule without reimplementing amortization math" do
    loan = loans(:one)
    payment = LiabilityPayment.build_from_schedule(
      loan: loan,
      payment_number: 1,
      canonical_key: "scheduled-loan-payment-1",
      fees: 12.50
    )

    breakdown = loan.payment_breakdown(payment_number: 1)

    assert_equal breakdown[:principal].amount, payment.principal_amount
    assert_equal breakdown[:interest].amount, payment.interest_amount
    assert_equal breakdown[:insurance].amount, payment.insurance_amount
    assert_equal breakdown[:total].amount + BigDecimal("12.5"), payment.total_amount
    assert payment.valid?
  end

  test "payments are immutable" do
    payment = LiabilityPayment.create!(
      family: families(:dylan_family),
      account: accounts(:loan),
      canonical_key: "immutable-payment",
      payment_date: Date.current,
      payment_type: "actual",
      total_amount: 100,
      principal_amount: 75,
      interest_amount: 25,
      currency: "USD"
    )

    assert_not payment.update(principal_amount: 80, interest_amount: 20)
    assert_includes payment.errors[:base], "liability payments are immutable"
  end
end

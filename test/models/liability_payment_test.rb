<sub>require "test_helper"

class LiabilityPaymentTest < ActiveSupport::TestCase
  test "principal is not financing expense" do
    loan = Loan.create!(subtype: "mortgage", interest_rate: 4, term_months: 360, rate_type: "fixed")
    account = Account.create!(
      family: families(:dylan_family),
      name: "Mortgage",
      balance: 250_000,
      currency: "USD",
      accountable: loan
    )

    payment = LiabilityPayment.create!(
      family: account.family,
      account: account,
      loan: loan,
      payment_date: Date.current,
      state: "actual",
      total_amount: 2000,
      principal_amount: 1250,
      interest_amount: 700,
      fee_amount: 50,
      insurance_amount: 0,
      currency: "USD"
    )

    assert_equal BigDecimal("750"), payment.financing_cost
    assert_equal BigDecimal("0"), payment.principal_net_worth_cost
    assert_equal BigDecimal("750"), payment.net_worth_cost
  end

  test "components must reconcile to total" do
    loan = Loan.create!(subtype: "mortgage", interest_rate: 4, term_months: 360, rate_type: "fixed")
    account = Account.create!(
      family: families(:dylan_family),
      name: "Mortgage",
      balance: 250_000,
      currency: "USD",
      accountable: loan
    )

    payment = LiabilityPayment.new(
      family: account.family,
      account: account,
      loan: loan,
      payment_date: Date.current,
      state: "actual",
      total_amount: 2000,
      principal_amount: 1250,
      interest_amount: 700,
      fee_amount: 0,
      insurance_amount: 0,
      currency: "USD"
    )

    assert_not payment.valid?
    assert_includes payment.errors[:total_amount], "must equal principal + interest + fees + insurance"
  end
  test "insurance is a separate cost from financing" do
    loan = Loan.create!(subtype: "mortgage", interest_rate: 4, term_months: 360, rate_type: "fixed")
    account = Account.create!(
      family: families(:dylan_family),
      name: "Mortgage Insurance",
      balance: 250_000,
      currency: "USD",
      accountable: loan
    )

    payment = LiabilityPayment.create!(
      family: account.family,
      account: account,
      loan: loan,
      payment_date: Date.current,
      state: "actual",
      total_amount: 2100,
      principal_amount: 1250,
      interest_amount: 700,
      fee_amount: 50,
      insurance_amount: 100,
      currency: "USD"
    )

    assert_equal BigDecimal("750"), payment.financing_cost
    assert_equal BigDecimal("100"), payment.insurance_cost
    assert_equal BigDecimal("850"), payment.net_worth_cost
  end
end
</sub>
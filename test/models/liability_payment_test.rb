require "test_helper"

class LiabilityPaymentTest < ActiveSupport::TestCase
  test "scheduled loan payment separates principal from financing cost" do
    account = build_loan_account
    payment = account.loan.amortization_schedule.payments.first

    record = LiabilityPayment.from_schedule!(loan: account.loan, payment: payment, fee_amount: 10)

    assert_equal payment.principal.amount, record.principal_amount
    assert_equal payment.interest.amount, record.interest_amount
    assert_equal payment.payment.amount + 10, record.total_amount
    assert_equal payment.interest.amount + 10, record.financing_cost_amount
    assert_equal payment.principal.amount, record.principal_reduction_amount
  end

  test "components must equal total" do
    payment = LiabilityPayment.new(
      family: families(:dylan_family),
      account: build_loan_account,
      kind: "actual",
      payment_date: Date.current,
      total_amount: 100,
      principal_amount: 80,
      interest_amount: 15,
      fee_amount: 1,
      currency: "USD"
    )

    assert_not payment.valid?
    assert_includes payment.errors[:total_amount], "must equal principal + interest + fees"
  end

  test "liability payment cannot be attached to asset account" do
    payment = LiabilityPayment.new(
      family: families(:dylan_family),
      account: accounts(:depository),
      kind: "actual",
      payment_date: Date.current,
      total_amount: 100,
      principal_amount: 90,
      interest_amount: 10,
      fee_amount: 0,
      currency: "USD"
    )

    assert_not payment.valid?
    assert_includes payment.errors[:account], "must be a liability account"
  end

  private

    def build_loan_account
      Account.create!(
        family: families(:dylan_family),
        name: "Phase 4 Mortgage",
        balance: 500_000,
        cash_balance: 0,
        currency: "USD",
        classification: "liability",
        accountable: Loan.create!(
          subtype: "mortgage",
          interest_rate: 3.5,
          term_months: 360,
          rate_type: "fixed",
          start_date: Date.new(2026, 1, 1)
        )
      ).tap do |account|
        account.update_columns(balance: 500_000)
        account.valuations.create!(
          amount: 500_000,
          currency: "USD",
          date: Date.new(2026, 1, 1),
          name: "Opening balance"
        ) unless account.valuations.exists?
      end
    end
end

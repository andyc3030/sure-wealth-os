require "test_helper"

class WealthOs::Liabilities::ScheduleDecomposerTest < ActiveSupport::TestCase
  test "persists the schedule's principal and interest separately" do
    loan = Loan.create!(
      subtype: "mortgage",
      interest_rate: 3.5,
      term_months: 360,
      rate_type: "fixed",
      start_date: Date.new(2026, 1, 1)
    )
    account = Account.create!(
      family: families(:dylan_family),
      name: "Mortgage",
      balance: 500_000,
      currency: "USD",
      accountable: loan
    )

    scheduled = loan.amortization_schedule.payments.first
    result = WealthOs::Liabilities::ScheduleDecomposer.call(
      loan: loan,
      payment_date: scheduled.date,
      fee_amount: 50
    )

    assert_equal scheduled.principal.amount, result.principal_amount
    assert_equal scheduled.interest.amount, result.interest_amount
    assert_equal scheduled.payment.amount + 50, result.total_amount
    assert_equal scheduled.interest.amount + 50, result.financing_cost
  end
  test "scheduled decomposition is idempotent and fails loudly on changed components" do
    loan = Loan.create!(
      subtype: "mortgage",
      interest_rate: 3.5,
      term_months: 360,
      rate_type: "fixed",
      start_date: Date.new(2026, 1, 1)
    )
    account = Account.create!(
      family: families(:dylan_family),
      name: "Mortgage Idempotency",
      balance: 500_000,
      currency: "USD",
      accountable: loan
    )

    scheduled = loan.amortization_schedule.payments.first

    first = WealthOs::Liabilities::ScheduleDecomposer.call(
      loan: loan,
      payment_date: scheduled.date,
      fee_amount: 50
    )
    second = WealthOs::Liabilities::ScheduleDecomposer.call(
      loan: loan,
      payment_date: scheduled.date,
      fee_amount: 50
    )

    assert_equal first.id, second.id

    assert_raises(WealthOs::Liabilities::ScheduleDecomposer::ScheduleConflict) do
      WealthOs::Liabilities::ScheduleDecomposer.call(
        loan: loan,
        payment_date: scheduled.date,
        fee_amount: 75
      )
    end
  end
  test "uses configured Sure loan insurance for scheduled decomposition" do
    loan = Loan.create!(
      subtype: "mortgage",
      interest_rate: 3.5,
      term_months: 12,
      rate_type: "fixed",
      start_date: Date.new(2026, 1, 1),
      insurance_rate: 1.2,
      insurance_rate_type: Loan::Insurance::LEVEL_TERM
    )
    Account.create!(
      family: families(:dylan_family),
      name: "Mortgage Insurance Schedule",
      balance: 120_000,
      currency: "USD",
      accountable: loan
    )

    scheduled = loan.amortization_schedule.payments.first
    premium = loan.insurance.premium_for(scheduled.number).amount.amount

    result = WealthOs::Liabilities::ScheduleDecomposer.call(
      loan: loan,
      payment_date: scheduled.date
    )

    assert_equal premium, result.insurance_amount
    assert_equal scheduled.payment.amount + premium, result.total_amount
  end

  test "schedule decomposer cannot create actual payment state" do
    loan = Loan.create!(
      subtype: "mortgage",
      interest_rate: 3.5,
      term_months: 12,
      rate_type: "fixed",
      start_date: Date.new(2026, 1, 1)
    )
    account = Account.create!(
      family: families(:dylan_family),
      name: "Mortgage Scheduled Only",
      balance: 120_000,
      currency: "USD",
      accountable: loan
    )

    scheduled = loan.amortization_schedule.payments.first

    assert_raises(ArgumentError) do
      WealthOs::Liabilities::ScheduleDecomposer.call(
        loan: loan,
        payment_date: scheduled.date,
        state: "actual"
      )
    end
  end
end

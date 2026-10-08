require "test_helper"

class WealthOs::Liabilities::ScheduleDecomposerTest < ActiveSupport::TestCase
  test "persists scheduled principal and interest separately" do
    loan = loans(:one)
    scheduled = loan.amortization_schedule.payments.first

    result = WealthOs::Liabilities::ScheduleDecomposer.call(
      loan: loan,
      payment_date: scheduled.date,
      fee_amount: 50
    )

    assert_equal scheduled.principal.amount, result.principal_amount
    assert_equal scheduled.interest.amount, result.interest_amount
    assert_equal scheduled.payment.amount + 50, result.total_amount
    assert_equal scheduled.interest.amount + 50, result.financing_cost_amount
  end

  test "scheduled decomposition is idempotent and fails loudly if components change" do
    loan = loans(:one)
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
end

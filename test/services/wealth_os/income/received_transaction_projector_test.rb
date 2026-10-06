require "test_helper"

class WealthOs::Income::ReceivedTransactionProjectorTest < ActiveSupport::TestCase
  test "projects booked dividend transaction once" do
    account = families(:empty).accounts.create!(
      name: "Broker",
      balance: 1000,
      cash_balance: 100,
      currency: "USD",
      accountable: Investment.new
    )

    entry = account.entries.create!(
      name: "Dividend",
      amount: -50,
      currency: "USD",
      date: Date.current,
      external_id: "div-1",
      source: "test_provider",
      entryable: Transaction.new(investment_activity_label: "Dividend")
    )

    first = WealthOs::Income::ReceivedTransactionProjector.call(entry)
    second = WealthOs::Income::ReceivedTransactionProjector.call(entry)

    assert_equal first.id, second.id
    assert_equal "dividend", first.income_type
    assert_equal "received", first.state
    assert_equal BigDecimal("50"), first.amount
    assert_equal BigDecimal("50"), first.received_cash
    assert_equal 1, IncomeEvent.where(family: account.family, event_key: first.event_key).count
  end

  test "ignores non-income activity" do
    account = families(:empty).accounts.create!(
      name: "Broker",
      balance: 1000,
      cash_balance: 100,
      currency: "USD",
      accountable: Investment.new
    )

    entry = account.entries.create!(
      name: "Transfer",
      amount: -50,
      currency: "USD",
      date: Date.current,
      external_id: "xfer-1",
      source: "test_provider",
      entryable: Transaction.new(investment_activity_label: "Transfer")
    )

    assert_nil WealthOs::Income::ReceivedTransactionProjector.call(entry)
  end
end

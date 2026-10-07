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
    assert_nil first.amount
    assert_nil first.tax_withheld
    assert_nil first.fees
    assert_equal BigDecimal("50"), first.received_cash
    assert_equal entry.id, first.entry_id
    assert_equal 1, IncomeEvent.where(family: account.family, event_key: first.event_key).count
  end

  test "same provider external id in different accounts creates distinct income lifecycles" do
    family = families(:empty)
    first_account = family.accounts.create!(
      name: "Broker One",
      balance: 1000,
      cash_balance: 100,
      currency: "USD",
      accountable: Investment.new
    )
    second_account = family.accounts.create!(
      name: "Broker Two",
      balance: 1000,
      cash_balance: 100,
      currency: "USD",
      accountable: Investment.new
    )

    entries = [ first_account, second_account ].map do |account|
      account.entries.create!(
        name: "Dividend",
        amount: -50,
        currency: "USD",
        date: Date.current,
        external_id: "shared-provider-id",
        source: "test_provider",
        entryable: Transaction.new(investment_activity_label: "Dividend")
      )
    end

    projected = entries.map { |entry| WealthOs::Income::ReceivedTransactionProjector.call(entry) }

    assert_equal 2, projected.map(&:id).uniq.size
    assert_equal [ first_account.id, second_account.id ].sort, projected.map(&:account_id).sort
    assert_equal 2, IncomeEvent.where(family: family, state: "received").where(event_key: projected.map(&:event_key)).count
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
  test "ignores a positive outflow even when labelled as income" do
    account = families(:empty).accounts.create!(
      name: "Broker Outflow",
      balance: 1000,
      cash_balance: 100,
      currency: "USD",
      accountable: Investment.new
    )

    entry = account.entries.create!(
      name: "Dividend adjustment",
      amount: 50,
      currency: "USD",
      date: Date.current,
      external_id: "div-outflow-1",
      source: "test_provider",
      entryable: Transaction.new(investment_activity_label: "Dividend")
    )

    assert_nil WealthOs::Income::ReceivedTransactionProjector.call(entry)
  end

  test "cash-only projection does not infer gross income or deductions" do
    account = families(:empty).accounts.create!(
      name: "Cash Only Income Broker",
      balance: 1000,
      cash_balance: 100,
      currency: "USD",
      accountable: Investment.new
    )

    entry = account.entries.create!(
      name: "Dividend",
      amount: -85,
      currency: "USD",
      date: Date.current,
      external_id: "div-net-cash",
      source: "test_provider",
      entryable: Transaction.new(investment_activity_label: "Dividend")
    )

    event = WealthOs::Income::ReceivedTransactionProjector.call(entry)

    assert_nil event.amount
    assert_nil event.tax_withheld
    assert_nil event.fees
    assert_equal BigDecimal("85"), event.cash_amount
    assert_equal "booked_transaction_cash_only", event.method
  end

end

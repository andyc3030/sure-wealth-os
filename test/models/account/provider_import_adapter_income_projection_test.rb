require "test_helper"

class Account::ProviderImportAdapterIncomeProjectionTest < ActiveSupport::TestCase
  test "explicit provider dividend label creates one received income lifecycle" do
    account = families(:empty).accounts.create!(
      name: "Authoritative Income Broker",
      balance: 1000,
      cash_balance: 100,
      currency: "USD",
      accountable: Investment.new
    )
    adapter = Account::ProviderImportAdapter.new(account)

    first = adapter.import_transaction(
      external_id: "provider-dividend-1",
      amount: -25,
      currency: "USD",
      date: Date.current,
      name: "Cash distribution",
      source: "test_provider",
      investment_activity_label: "Dividend"
    )
    second = adapter.import_transaction(
      external_id: "provider-dividend-1",
      amount: -25,
      currency: "USD",
      date: Date.current,
      name: "Cash distribution",
      source: "test_provider",
      investment_activity_label: "Dividend"
    )

    key = [ "entry", first.id, "dividend" ].join(":")
    events = IncomeEvent.where(family: account.family, event_key: key)

    assert_equal first.id, second.id
    assert_equal 1, events.count
    assert_equal "received", events.first.state
    assert_nil events.first.amount
    assert_equal first.id, events.first.entry_id
    assert_equal BigDecimal("25"), events.first.received_cash
  end

  test "name heuristic alone does not create an accounting income event" do
    account = families(:empty).accounts.create!(
      name: "Heuristic Income Broker",
      balance: 1000,
      cash_balance: 100,
      currency: "USD",
      accountable: Investment.new
    )
    adapter = Account::ProviderImportAdapter.new(account)

    entry = adapter.import_transaction(
      external_id: "heuristic-dividend-1",
      amount: -25,
      currency: "USD",
      date: Date.current,
      name: "Dividend",
      source: "test_provider"
    )

    assert_equal "Dividend", entry.transaction.investment_activity_label
    assert_empty IncomeEvent.where(family: account.family)
  end
end

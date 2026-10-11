require "test_helper"

class Account::ProviderImportAdapterSourceLineageTest < ActiveSupport::TestCase
  test "transaction import retains immutable raw source lineage" do
    account = accounts(:depository)
    raw = RawSourceRecord.ingest!(
      family: account.family,
      account: account,
      source_system: "test_provider",
      record_type: "transaction",
      source_key: "txn-lineage-1",
      payload: { "id" => "txn-lineage-1", "amount" => "42.50" }
    )

    entry = Account::ProviderImportAdapter.new(account).import_transaction(
      external_id: "txn-lineage-1",
      amount: 42.50,
      currency: "USD",
      date: 10.days.ago.to_date,
      name: "Lineage Test",
      source: "test_provider",
      raw_source_record: raw
    )

    assert_equal raw, entry.raw_source_record
  end

  test "holding import retains immutable raw source lineage" do
    account = accounts(:investment)
    raw = RawSourceRecord.ingest!(
      family: account.family,
      account: account,
      source_system: "test_provider",
      record_type: "holding",
      source_key: "holding-lineage-1",
      payload: { "ticker" => "AAPL", "quantity" => "3" }
    )

    holding = Account::ProviderImportAdapter.new(account).import_holding(
      security: securities(:aapl),
      quantity: 3,
      amount: 600,
      currency: "USD",
      date: 15.days.ago.to_date,
      price: 200,
      external_id: "holding-lineage-1",
      source: "test_provider",
      raw_source_record: raw
    )

    assert_equal raw, holding.raw_source_record
  end
end

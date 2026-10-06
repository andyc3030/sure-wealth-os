require "test_helper"

class RawSourceRecordTest < ActiveSupport::TestCase
  test "ingest is idempotent for identical source content and canonicalizes payload" do
    family = families(:dylan_family)
    account = accounts(:depository)

    first = RawSourceRecord.ingest!(
      family: family,
      account: account,
      source_system: "plaid",
      record_type: "account_balance",
      source_key: "acct-123",
      payload: { "z" => 2, "a" => { "y" => 2, "x" => 1 } },
      observed_at: Time.current
    )

    second = RawSourceRecord.ingest!(
      family: family,
      account: account,
      source_system: "plaid",
      record_type: "account_balance",
      source_key: "acct-123",
      payload: { "a" => { "x" => 1, "y" => 2 }, "z" => 2 },
      observed_at: 1.minute.from_now
    )

    assert_equal first.id, second.id
    assert_equal({ "a" => { "x" => 1, "y" => 2 }, "z" => 2 }, first.payload)
    assert_equal RawSourceRecord.digest_for(first.payload), first.payload_sha256
  end

  test "different source content creates a new immutable version" do
    family = families(:dylan_family)

    first = RawSourceRecord.ingest!(
      family: family,
      source_system: "manual",
      record_type: "account_balance",
      source_key: "kent-reliance",
      payload: { "balance" => "1000.00" }
    )
    second = RawSourceRecord.ingest!(
      family: family,
      source_system: "manual",
      record_type: "account_balance",
      source_key: "kent-reliance",
      payload: { "balance" => "1100.00" }
    )

    assert_not_equal first.id, second.id
    assert_not first.update(source_key: "changed")
    assert_includes first.errors[:base], "raw source records are immutable"
    assert_not first.destroy
    assert RawSourceRecord.exists?(first.id)
  end
end

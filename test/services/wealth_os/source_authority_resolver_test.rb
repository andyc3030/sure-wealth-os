require "test_helper"

class WealthOs::SourceAuthorityResolverTest < ActiveSupport::TestCase
  test "selects highest authority source and records disagreement" do
    family = families(:dylan_family)
    account = accounts(:depository)

    SourceAuthorityRule.create!(
      family: family,
      record_type: "account_balance",
      field_name: "balance.available",
      source_system: "plaid",
      priority: 10
    )
    SourceAuthorityRule.create!(
      family: family,
      record_type: "account_balance",
      field_name: "balance.available",
      source_system: "manual",
      priority: 20
    )

    plaid = RawSourceRecord.ingest!(
      family: family,
      account: account,
      source_system: "plaid",
      record_type: "account_balance",
      source_key: "acct",
      payload: { "balance" => { "available" => "100.00" } },
      observed_at: Time.current
    )
    manual = RawSourceRecord.ingest!(
      family: family,
      account: account,
      source_system: "manual",
      record_type: "account_balance",
      source_key: "acct",
      payload: { "balance" => { "available" => "95.00" } },
      observed_at: 1.minute.ago
    )

    result = WealthOs::SourceAuthorityResolver.new(
      family: family,
      account: account,
      record_type: "account_balance",
      field_name: "balance.available"
    ).resolve(records: [ manual, plaid ])

    assert_equal plaid, result.selected_record
    assert_equal "100.00", result.selected_value
    assert_equal 10, result.rule.priority
    assert_equal "open", result.conflict.status
    assert_equal plaid, result.conflict.selected_source_record
  end

  test "fails loudly when no authority rule exists" do
    family = families(:dylan_family)
    record = RawSourceRecord.ingest!(
      family: family,
      source_system: "manual",
      record_type: "property_value",
      source_key: "house",
      payload: { "value" => "500000" }
    )

    resolver = WealthOs::SourceAuthorityResolver.new(
      family: family,
      record_type: "property_value",
      field_name: "value"
    )

    assert_raises(WealthOs::SourceAuthorityResolver::MissingAuthorityRule) do
      resolver.resolve(records: [ record ])
    end
  end
end

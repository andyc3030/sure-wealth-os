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
  test "a resolved conflict is not recreated for the same immutable raw pair" do
    family = families(:dylan_family)
    account = accounts(:depository)

    SourceAuthorityRule.create!(
      family: family,
      record_type: "cash",
      field_name: "value",
      source_system: "plaid",
      priority: 10
    )
    SourceAuthorityRule.create!(
      family: family,
      record_type: "cash",
      field_name: "value",
      source_system: "manual",
      priority: 20
    )

    plaid = RawSourceRecord.ingest!(
      family: family,
      account: account,
      source_system: "plaid",
      record_type: "cash",
      source_key: "cash-a",
      payload: { "value" => "100" }
    )
    manual = RawSourceRecord.ingest!(
      family: family,
      account: account,
      source_system: "manual",
      record_type: "cash",
      source_key: "cash-b",
      payload: { "value" => "90" }
    )

    resolver = WealthOs::SourceAuthorityResolver.new(
      family: family,
      account: account,
      record_type: "cash",
      field_name: "value"
    )

    first = resolver.resolve(records: [ plaid, manual ])
    first.conflict.resolve!(selected_source_record: plaid, rule: "plaid_authoritative")
    second = resolver.resolve(records: [ plaid, manual ])

    assert_equal first.conflict.id, second.conflict.id
    assert_equal "resolved", second.conflict.status
    assert_equal 1, SourceConflict.where(
      source_record_a: first.conflict.source_record_a,
      source_record_b: first.conflict.source_record_b,
      field_name: "value"
    ).count
  end
end

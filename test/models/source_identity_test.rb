require "test_helper"

class SourceIdentityTest < ActiveSupport::TestCase
  test "resolution is idempotent until the canonical mapping changes" do
    family = families(:dylan_family)
    first_account = accounts(:depository)
    second_account = accounts(:investment)

    first = SourceIdentity.resolve!(
      family: family,
      source_system: "plaid",
      entity_type: "account",
      external_id: "external-123",
      canonical: first_account
    )

    same = SourceIdentity.resolve!(
      family: family,
      source_system: "plaid",
      entity_type: "account",
      external_id: "external-123",
      canonical: first_account
    )

    replacement = SourceIdentity.resolve!(
      family: family,
      source_system: "plaid",
      entity_type: "account",
      external_id: "external-123",
      canonical: second_account,
      confidence: 0.95
    )

    assert_equal first.id, same.id
    assert_not_equal first.id, replacement.id
    assert_equal first.id, replacement.supersedes_id
    assert_equal second_account, replacement.canonical
    assert_not first.update(confidence: 0.5)
  end
end

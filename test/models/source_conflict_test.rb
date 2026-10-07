require "test_helper"

class SourceConflictTest < ActiveSupport::TestCase
  test "selected source must be one side of the conflict and resolved conflicts freeze" do
    family = families(:dylan_family)
    a = RawSourceRecord.ingest!(
      family: family,
      source_system: "plaid",
      record_type: "balance",
      source_key: "a",
      payload: { "value" => "100" }
    )
    b = RawSourceRecord.ingest!(
      family: family,
      source_system: "manual",
      record_type: "balance",
      source_key: "b",
      payload: { "value" => "90" }
    )
    third = RawSourceRecord.ingest!(
      family: family,
      source_system: "statement",
      record_type: "balance",
      source_key: "c",
      payload: { "value" => "95" }
    )

    invalid = SourceConflict.new(
      family: family,
      field_name: "value",
      source_record_a: a,
      source_record_b: b,
      selected_source_record: third,
      detected_at: Time.current
    )
    assert_not invalid.valid?
    assert_includes invalid.errors[:selected_source_record], "must be one side of the conflict"

    conflict = SourceConflict.detect!(
      family: family,
      field_name: "value",
      record_a: a,
      record_b: b,
      value_a: "100",
      value_b: "90",
      selected_source_record: a
    )
    conflict.resolve!(selected_source_record: a, rule: "plaid_authoritative")

    assert_not conflict.update(resolution_rule: "changed_after_resolution")
    assert_includes conflict.errors[:base], "resolved or ignored conflicts are immutable"
  end
end

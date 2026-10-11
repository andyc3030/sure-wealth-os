require "test_helper"

class SourceTraceableTest < ActiveSupport::TestCase
  test "rejects raw lineage from another family" do
    holding = holdings(:one)
    foreign_record = RawSourceRecord.ingest!(
      family: families(:empty),
      source_system: "manual",
      record_type: "holding",
      source_key: "foreign",
      payload: { "qty" => "10" }
    )

    holding.raw_source_record = foreign_record

    assert_not holding.valid?
    assert_includes holding.errors[:raw_source_record], "must belong to the same family"
  end
end

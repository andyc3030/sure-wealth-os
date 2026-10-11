require "test_helper"

class WealthOs::Reconciliation::NumericComparatorTest < ActiveSupport::TestCase
  test "records passed warning and failed reconciliation outcomes" do
    family = families(:dylan_family)
    account = accounts(:depository)

    passed = WealthOs::Reconciliation::NumericComparator.call(
      family: family,
      account: account,
      kind: "balance",
      expected: 100,
      actual: 100.50,
      tolerance: 1,
      materiality_threshold: 10,
      currency: "USD"
    )
    warning = WealthOs::Reconciliation::NumericComparator.call(
      family: family,
      account: account,
      kind: "balance",
      expected: 100,
      actual: 105,
      tolerance: 1,
      materiality_threshold: 10,
      currency: "USD"
    )
    failed = WealthOs::Reconciliation::NumericComparator.call(
      family: family,
      account: account,
      kind: "balance",
      expected: 100,
      actual: 120,
      tolerance: 1,
      materiality_threshold: 10,
      currency: "USD"
    )

    assert_equal "passed", passed.status
    assert_equal "warning", warning.status
    assert_equal "failed", failed.status
    assert failed.material
  end

  test "dedupe key makes reruns idempotent and events are append-only" do
    family = families(:dylan_family)

    first = WealthOs::Reconciliation::NumericComparator.call(
      family: family,
      kind: "cash",
      expected: 100,
      actual: 100,
      tolerance: 0,
      dedupe_key: "daily-close-2026-10-06-cash"
    )

    second = WealthOs::Reconciliation::NumericComparator.call(
      family: family,
      kind: "cash",
      expected: 100,
      actual: 100,
      tolerance: 0,
      dedupe_key: "daily-close-2026-10-06-cash"
    )

    assert_equal first.id, second.id
    assert_not first.update(status: "failed")
    assert_not first.destroy
  end
end

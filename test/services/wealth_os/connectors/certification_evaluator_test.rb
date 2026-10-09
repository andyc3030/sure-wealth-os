# frozen_string_literal: true

require "test_helper"

class WealthOs::Connectors::CertificationEvaluatorTest < ActiveSupport::TestCase
  setup do
    @family = families(:dylan_family)
    @profile = WealthOs::Connectors::CertificationPolicy.profile!("ctrader")
    @reviewer = users(:family_admin)
  end

  test "passes cTrader only with accounts scope and every required live check" do
    checks = @profile.required_checks.index_with { true }
    evidence = @profile.required_checks.index_with { |key| "evidence for #{key}" }

    certification = WealthOs::Connectors::CertificationEvaluator.call(
      family: @family,
      provider_key: "ctrader",
      institution_key: "ic_markets",
      environment: "production",
      reviewed_by: @reviewer,
      observed_scope: "accounts",
      checks: checks,
      evidence: evidence,
      checked_at: Time.zone.parse("2026-10-09 00:00:00")
    )

    assert certification.passed?
    assert_equal "accounts", certification.expected_scope
    assert_equal true, certification.checks.fetch("_scope_matches")
    assert_equal [], certification.checks.fetch("_missing_checks")
    assert_equal [], certification.checks.fetch("_missing_evidence")
  end

  test "fails when a required check has no evidence" do
    checks = @profile.required_checks.index_with { true }
    evidence = @profile.required_checks.index_with { |key| "evidence for #{key}" }.except("reconciliation")

    certification = WealthOs::Connectors::CertificationEvaluator.call(
      family: @family,
      provider_key: "ctrader",
      institution_key: "ic_markets",
      environment: "production",
      reviewed_by: @reviewer,
      observed_scope: "accounts",
      checks: checks,
      evidence: evidence
    )

    assert_equal "failed", certification.status
    assert_includes certification.checks.fetch("_missing_evidence"), "reconciliation"
  end

  test "fails closed on trading scope or missing checks" do
    checks = @profile.required_checks.index_with { true }.except("revocation")

    certification = WealthOs::Connectors::CertificationEvaluator.call(
      family: @family,
      provider_key: "ctrader",
      institution_key: "ic_markets",
      environment: "production",
      reviewed_by: @reviewer,
      observed_scope: "trading",
      checks: checks,
      evidence: { "test_run" => "demo/live acceptance evidence" }
    )

    assert_equal "failed", certification.status
    assert_equal false, certification.checks.fetch("_scope_matches")
    assert_includes certification.checks.fetch("_missing_checks"), "revocation"
  end

  test "production gate uses latest production certification and expires closed" do
    checks = @profile.required_checks.index_with { true }
    evidence = @profile.required_checks.index_with { |key| "evidence for #{key}" }
    checked_at = Time.zone.parse("2026-10-01 12:00:00")

    certification = WealthOs::Connectors::CertificationEvaluator.call(
      family: @family,
      provider_key: "ctrader",
      institution_key: "ic_markets",
      environment: "production",
      reviewed_by: @reviewer,
      observed_scope: "accounts",
      checks: checks,
      evidence: evidence,
      checked_at: checked_at
    )

    result = WealthOs::Connectors::ProductionGate.call(
      family: @family,
      provider_key: "ctrader",
      institution_key: "ic_markets",
      at: checked_at + 1.day
    )
    assert result.approved
    assert_equal certification.id, result.certification.id

    expired = WealthOs::Connectors::ProductionGate.call(
      family: @family,
      provider_key: "ctrader",
      institution_key: "ic_markets",
      at: certification.review_due_at + 1.second
    )
    assert_equal false, expired.approved
    assert_equal "certification_review_overdue", expired.reason
  end

  test "production gate fails if reviewer is removed after certification" do
    checks = @profile.required_checks.index_with { true }
    evidence = @profile.required_checks.index_with { |key| "evidence for #{key}" }

    certification = WealthOs::Connectors::CertificationEvaluator.call(
      family: @family,
      provider_key: "ctrader",
      institution_key: "ic_markets",
      environment: "production",
      reviewed_by: @reviewer,
      observed_scope: "accounts",
      checks: checks,
      evidence: evidence
    )
    certification.update_column(:reviewed_by_id, nil)

    result = WealthOs::Connectors::ProductionGate.call(
      family: @family,
      provider_key: "ctrader",
      institution_key: "ic_markets"
    )

    assert_equal false, result.approved
    assert_equal "certification_reviewer_missing", result.reason
  end

  test "a later failed certification revokes earlier approval" do
    checks = @profile.required_checks.index_with { true }
    evidence = @profile.required_checks.index_with { |key| "evidence for #{key}" }

    first = WealthOs::Connectors::CertificationEvaluator.call(
      family: @family,
      provider_key: "ctrader",
      institution_key: "ic_markets",
      environment: "production",
      reviewed_by: @reviewer,
      observed_scope: "accounts",
      checks: checks,
      evidence: evidence,
      checked_at: 2.days.ago
    )
    failed = WealthOs::Connectors::CertificationEvaluator.call(
      family: @family,
      provider_key: "ctrader",
      institution_key: "ic_markets",
      environment: "production",
      reviewed_by: @reviewer,
      observed_scope: "trading",
      checks: checks,
      evidence: evidence,
      checked_at: 1.day.ago
    )

    assert_equal first.id, failed.supersedes_id

    result = WealthOs::Connectors::ProductionGate.call(
      family: @family,
      provider_key: "ctrader",
      institution_key: "ic_markets"
    )
    assert_equal false, result.approved
    assert_equal "latest_certification_failed", result.reason
  end
end

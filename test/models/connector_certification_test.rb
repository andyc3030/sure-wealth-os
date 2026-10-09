# frozen_string_literal: true

require "test_helper"

class ConnectorCertificationTest < ActiveSupport::TestCase
  setup do
    @family = families(:dylan_family)
  end

  test "production approval requires a passed non-overdue production record" do
    certification = build_certification(
      status: "passed",
      environment: "production",
      review_due_at: 30.days.from_now
    )

    assert certification.production_approved?
  end

  test "production pass requires a family administrator reviewer" do
    profile = WealthOs::Connectors::CertificationPolicy.profile!("ctrader")
    checks = profile.required_checks.index_with { true }
    evidence = profile.required_checks.index_with { |key| "evidence for #{key}" }

    certification = ConnectorCertification.new(
      family: @family,
      provider_key: "ctrader",
      institution_key: "ic_markets",
      route_type: profile.route_type,
      environment: "production",
      status: "passed",
      expected_scope: profile.expected_scope,
      observed_scope: profile.expected_scope,
      checks: checks,
      evidence: evidence,
      checked_at: Time.current,
      review_due_at: 30.days.from_now
    )

    assert_not certification.valid?
    assert_includes certification.errors[:reviewed_by],
      "is required for production certification"
  end

  test "direct optimistic status cannot bypass deterministic policy" do
    certification = ConnectorCertification.new(
      family: @family,
      provider_key: "ctrader",
      institution_key: "ic_markets",
      route_type: "direct_api",
      environment: "production",
      status: "passed",
      expected_scope: "accounts",
      observed_scope: "accounts",
      checks: {},
      evidence: {},
      checked_at: Time.current,
      review_due_at: 30.days.from_now
    )

    assert_not certification.valid?
    assert certification.errors[:status].any? { |message| message.include?("deterministic policy result failed") }
  end

  test "certification records are immutable" do
    certification = build_certification

    assert_not certification.update(notes: "changed")
    assert_includes certification.errors[:base], "connector certifications are immutable"
  end

  test "secret-bearing evidence keys are rejected" do
    certification = ConnectorCertification.new(
      family: @family,
      provider_key: "ctrader",
      institution_key: "ic_markets",
      route_type: "direct_api",
      environment: "demo",
      status: "failed",
      expected_scope: "accounts",
      observed_scope: "accounts",
      checks: {},
      evidence: { "oauth" => { "access_token" => "must-not-be-stored" } },
      checked_at: Time.current,
      review_due_at: 30.days.from_now
    )

    assert_not certification.valid?
    assert certification.errors[:evidence].any? { |message| message.include?("access_token") }
  end

  test "superseding record must describe the same route" do
    previous = build_certification
    candidate = ConnectorCertification.new(
      family: @family,
      provider_key: "snaptrade",
      institution_key: "schwab",
      route_type: "aggregator_brokerage",
      environment: "production",
      status: "failed",
      expected_scope: "read",
      observed_scope: "read",
      checks: {},
      evidence: {},
      checked_at: Time.current,
      review_due_at: 30.days.from_now,
      supersedes: previous
    )

    assert_not candidate.valid?
    assert_includes candidate.errors[:supersedes],
      "must certify the same family/provider/institution/account route"
  end

  private

    def build_certification(status: "failed", environment: "demo", review_due_at: 30.days.from_now)
      profile = WealthOs::Connectors::CertificationPolicy.profile!("ctrader")
      checks = profile.required_checks.index_with { status == "passed" }
      evidence = profile.required_checks.index_with { |key| status == "passed" ? "evidence for #{key}" : nil }.compact

      ConnectorCertification.create!(
        family: @family,
        provider_key: "ctrader",
        institution_key: "ic_markets",
        route_type: "direct_api",
        environment: environment,
        status: status,
        reviewed_by: environment == "production" ? users(:family_admin) : nil,
        expected_scope: "accounts",
        observed_scope: "accounts",
        checks: checks,
        evidence: evidence,
        checked_at: Time.current,
        review_due_at: review_due_at
      )
    end
end

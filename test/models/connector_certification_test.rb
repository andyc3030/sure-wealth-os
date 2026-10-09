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
      checked_at: Time.current
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
      supersedes: previous
    )

    assert_not candidate.valid?
    assert_includes candidate.errors[:supersedes],
      "must certify the same family/provider/institution/account route"
  end

  private

    def build_certification(status: "failed", environment: "demo", review_due_at: nil)
      ConnectorCertification.create!(
        family: @family,
        provider_key: "ctrader",
        institution_key: "ic_markets",
        route_type: "direct_api",
        environment: environment,
        status: status,
        expected_scope: "accounts",
        observed_scope: "accounts",
        checks: {},
        evidence: { "account_identity" => "verified against provider account display" },
        checked_at: Time.current,
        review_due_at: review_due_at
      )
    end
end

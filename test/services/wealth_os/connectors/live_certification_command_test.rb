# frozen_string_literal: true

require "test_helper"
require "tempfile"

class WealthOs::Connectors::LiveCertificationCommandTest < ActiveSupport::TestCase
  setup do
    @family = families(:dylan_family)
    @reviewer = users(:family_admin)
    @profile = WealthOs::Connectors::CertificationPolicy.profile!("ctrader")
  end

  test "creates a production-approved immutable certification from complete live evidence" do
    payload = {
      environment: "production",
      provider_key: "ctrader",
      institution_key: "ic_markets",
      observed_scope: "accounts",
      checks: @profile.required_checks.index_with { true },
      evidence: @profile.required_checks.index_with { |key| "verified live evidence for #{key}" },
      notes: "test live certification command"
    }

    with_payload(payload) do |path|
      result = WealthOs::Connectors::LiveCertificationCommand.call(
        family_id: @family.id,
        reviewer_email: @reviewer.email,
        evidence_file: path,
        confirm_live: true,
        checked_at: Time.zone.parse("2026-10-09 12:00:00")
      )

      assert result.certification.passed?
      assert result.gate.approved
      assert_equal "production_certified", result.gate.reason
      assert_equal "production", result.certification.environment
      assert_equal "ctrader", result.certification.provider_key
      assert_equal "ic_markets", result.certification.institution_key
    end
  end

  test "requires an explicit live confirmation" do
    with_payload(valid_payload) do |path|
      error = assert_raises(ArgumentError) do
        WealthOs::Connectors::LiveCertificationCommand.call(
          family_id: @family.id,
          reviewer_email: @reviewer.email,
          evidence_file: path,
          confirm_live: false
        )
      end

      assert_equal "CONFIRM_LIVE must be YES", error.message
    end
  end

  test "refuses non-production evidence files" do
    payload = valid_payload.merge(environment: "demo")

    with_payload(payload) do |path|
      error = assert_raises(ArgumentError) do
        WealthOs::Connectors::LiveCertificationCommand.call(
          family_id: @family.id,
          reviewer_email: @reviewer.email,
          evidence_file: path,
          confirm_live: true
        )
      end

      assert_equal "environment must be production", error.message
    end
  end

  private

    def valid_payload
      {
        environment: "production",
        provider_key: "ctrader",
        institution_key: "ic_markets",
        observed_scope: "accounts",
        checks: @profile.required_checks.index_with { true },
        evidence: @profile.required_checks.index_with { |key| "verified live evidence for #{key}" }
      }
    end

    def with_payload(payload)
      Tempfile.create([ "wealth-os-live-certification", ".json" ]) do |file|
        file.write(JSON.generate(payload))
        file.flush
        yield file.path
      end
    end
end

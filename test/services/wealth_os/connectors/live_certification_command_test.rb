# frozen_string_literal: true

require "test_helper"
require "tempfile"

class WealthOs::Connectors::LiveCertificationCommandTest < ActiveSupport::TestCase
  setup do
    @family = families(:dylan_family)
    @reviewer = users(:family_admin)
    @account = accounts(:connected)
  end

  test "creates a production-approved Revolut Plaid certification from complete live evidence" do
    profile = WealthOs::Connectors::CertificationPolicy.profile!("plaid_uk")
    payload = valid_payload(
      provider_key: "plaid_uk",
      institution_key: "ins_63",
      observed_scope: profile.expected_scope
    )

    with_payload(payload) do |path|
      result = WealthOs::Connectors::LiveCertificationCommand.call(
        family_id: @family.id,
        reviewer_email: @reviewer.email,
        account_id: @account.id,
        evidence_file: path,
        confirm_live: true,
        checked_at: Time.zone.parse("2026-10-14 12:00:00")
      )

      assert result.certification.passed?
      assert result.gate.approved
      assert_equal "production_certified", result.gate.reason
      assert_equal "production", result.certification.environment
      assert_equal "plaid_uk", result.certification.provider_key
      assert_equal "ins_63", result.certification.institution_key
      assert_equal @account.id, result.certification.account_id
    end
  end

  test "creates a production-approved verified manual certification" do
    profile = WealthOs::Connectors::CertificationPolicy.profile!("verified_manual")
    payload = valid_payload(
      provider_key: "verified_manual",
      institution_key: "official-statement-route",
      observed_scope: profile.expected_scope
    )

    with_payload(payload) do |path|
      result = WealthOs::Connectors::LiveCertificationCommand.call(
        family_id: @family.id,
        reviewer_email: @reviewer.email,
        account_id: @account.id,
        evidence_file: path,
        confirm_live: true
      )

      assert result.certification.passed?
      assert result.gate.approved
      assert_equal "verified_manual", result.certification.provider_key
    end
  end

  test "requires explicit live confirmation" do
    with_payload(plaid_payload) do |path|
      error = assert_raises(ArgumentError) do
        WealthOs::Connectors::LiveCertificationCommand.call(
          family_id: @family.id,
          reviewer_email: @reviewer.email,
          account_id: @account.id,
          evidence_file: path,
          confirm_live: false
        )
      end

      assert_equal "CONFIRM_LIVE must be YES", error.message
    end
  end

  test "refuses non-production evidence files" do
    payload = plaid_payload.merge(environment: "demo")

    with_payload(payload) do |path|
      error = assert_raises(ArgumentError) do
        WealthOs::Connectors::LiveCertificationCommand.call(
          family_id: @family.id,
          reviewer_email: @reviewer.email,
          account_id: @account.id,
          evidence_file: path,
          confirm_live: true
        )
      end

      assert_equal "environment must be production", error.message
    end
  end

  test "rejects cTrader because it is excluded from Phase 13" do
    profile = WealthOs::Connectors::CertificationPolicy.profile!("ctrader")
    payload = valid_payload(
      provider_key: "ctrader",
      institution_key: "ic_markets",
      observed_scope: profile.expected_scope
    )

    with_payload(payload) do |path|
      error = assert_raises(ArgumentError) do
        WealthOs::Connectors::LiveCertificationCommand.call(
          family_id: @family.id,
          reviewer_email: @reviewer.email,
          account_id: @account.id,
          evidence_file: path,
          confirm_live: true
        )
      end

      assert_equal "cTrader is excluded from Phase 13 live certification", error.message
    end
  end

  private

    def plaid_payload
      profile = WealthOs::Connectors::CertificationPolicy.profile!("plaid_uk")
      valid_payload(provider_key: "plaid_uk", institution_key: "ins_63", observed_scope: profile.expected_scope)
    end

    def valid_payload(provider_key:, institution_key:, observed_scope:)
      profile = WealthOs::Connectors::CertificationPolicy.profile!(provider_key)
      {
        environment: "production",
        provider_key: provider_key,
        institution_key: institution_key,
        observed_scope: observed_scope,
        checks: profile.required_checks.index_with { true },
        evidence: profile.required_checks.index_with { |key| "verified live evidence for #{key}" }
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

# frozen_string_literal: true

namespace :wealth_os do
  desc "Create an immutable Phase 13 production connector certification from a live evidence JSON file"
  task certify_connector: :environment do
    required = %w[FAMILY_ID REVIEWER_EMAIL EVIDENCE_FILE CONFIRM_LIVE]
    missing = required.select { |key| ENV[key].blank? }

    if missing.any?
      warn({ ok: false, error: "missing_environment", missing: missing }.to_json)
      abort
    end

    unless ENV["CONFIRM_LIVE"] == "YES"
      warn({ ok: false, error: "confirmation_required", message: "Set CONFIRM_LIVE=YES only after completing real-provider checks." }.to_json)
      abort
    end

    result = WealthOs::Connectors::LiveCertificationCommand.call(
      family_id: ENV.fetch("FAMILY_ID"),
      reviewer_email: ENV.fetch("REVIEWER_EMAIL"),
      account_id: ENV["ACCOUNT_ID"].presence,
      evidence_file: ENV.fetch("EVIDENCE_FILE"),
      confirm_live: true
    )

    certification = result.certification

    puts({
      ok: result.gate.approved,
      certification_id: certification.id,
      provider_key: certification.provider_key,
      institution_key: certification.institution_key,
      environment: certification.environment,
      status: certification.status,
      production_gate: result.gate.reason,
      checked_at: certification.checked_at.iso8601,
      review_due_at: certification.review_due_at.iso8601,
      evidence_sha256: certification.evidence_sha256,
      missing_checks: certification.checks["_missing_checks"],
      missing_evidence: certification.checks["_missing_evidence"]
    }.to_json)

    abort unless result.gate.approved
  rescue JSON::ParserError, KeyError, ActiveRecord::RecordNotFound, ArgumentError, ActiveRecord::RecordInvalid => error
    warn({ ok: false, error: error.class.name, message: error.message }.to_json)
    abort
  end
end

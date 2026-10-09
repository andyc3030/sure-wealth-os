# frozen_string_literal: true

require "json"

module WealthOs
  module Connectors
    class LiveCertificationCommand
      Result = Data.define(:certification, :gate)

      def self.call(family_id:, reviewer_email:, evidence_file:, account_id: nil,
                    confirm_live: false, checked_at: Time.current)
        raise ArgumentError, "CONFIRM_LIVE must be YES" unless confirm_live == true

        payload = JSON.parse(File.read(evidence_file))
        raise ArgumentError, "environment must be production" unless payload.fetch("environment") == "production"

        family = Family.find(family_id)
        reviewer = family.users.find_by!(email: reviewer_email)
        account = account_id.present? ? family.accounts.find(account_id) : nil

        certification = CertificationEvaluator.call(
          family: family,
          account: account,
          provider_key: payload.fetch("provider_key"),
          institution_key: payload.fetch("institution_key"),
          environment: "production",
          reviewed_by: reviewer,
          observed_scope: payload.fetch("observed_scope"),
          checks: payload.fetch("checks"),
          evidence: payload.fetch("evidence"),
          checked_at: checked_at,
          notes: payload["notes"]
        )

        gate = ProductionGate.call(
          family: family,
          account: account,
          provider_key: payload.fetch("provider_key"),
          institution_key: payload.fetch("institution_key"),
          at: checked_at
        )

        Result.new(certification, gate)
      end
    end
  end
end

# frozen_string_literal: true

module WealthOs
  module Connectors
    class CertificationEvaluator
      def self.call(family:, provider_key:, institution_key:, environment:, observed_scope:,
                    checks:, evidence:, account: nil, reviewed_by: nil, checked_at: Time.current, notes: nil)
        profile = CertificationPolicy.profile!(provider_key)
        result = CertificationPolicy.evaluate(
          provider_key: provider_key,
          observed_scope: observed_scope,
          checks: checks,
          evidence: evidence
        )

        previous = ConnectorCertification.where(
          family_id: family.id,
          account_id: account&.id,
          provider_key: provider_key.to_s,
          institution_key: institution_key.to_s
        ).latest_first.first

        ConnectorCertification.create!(
          family: family,
          account: account,
          provider_key: provider_key.to_s,
          institution_key: institution_key.to_s,
          route_type: profile.route_type,
          environment: environment.to_s,
          status: result.fetch(:passed) ? "passed" : "failed",
          reviewed_by: reviewed_by,
          expected_scope: profile.expected_scope,
          observed_scope: observed_scope.to_s,
          checks: checks.to_h.stringify_keys.merge(
            "_scope_matches" => result.fetch(:scope_matches),
            "_missing_checks" => result.fetch(:missing_checks),
            "_missing_evidence" => result.fetch(:missing_evidence)
          ),
          evidence: evidence,
          checked_at: checked_at,
          review_due_at: checked_at + profile.review_interval_days.days,
          supersedes: previous,
          notes: notes
        )
      end
    end
  end
end

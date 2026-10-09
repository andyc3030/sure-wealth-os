# frozen_string_literal: true

module WealthOs
  module Connectors
    class ProductionGate
      Result = Data.define(:approved, :reason, :certification)

      def self.call(family:, provider_key:, institution_key:, account: nil, at: Time.current)
        certification = ConnectorCertification.where(
          family_id: family.id,
          account_id: account&.id,
          provider_key: provider_key.to_s,
          institution_key: institution_key.to_s,
          environment: "production"
        ).latest_first.first

        return Result.new(false, "no_production_certification", nil) unless certification
        return Result.new(false, "latest_certification_failed", certification) unless certification.passed?
        return Result.new(false, "certification_review_missing", certification) if certification.review_due_at.blank?
        return Result.new(false, "certification_review_overdue", certification) if certification.review_due_at < at

        Result.new(true, "production_certified", certification)
      end
    end
  end
end

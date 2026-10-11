# frozen_string_literal: true

module WealthOs
  module Reconciliation
    class NumericComparator
      class << self
        def call(family:, kind:, expected:, actual:, tolerance:, materiality_threshold: nil,
                 account: nil, account_provider: nil, subject: nil, raw_source_record: nil,
                 currency: nil, dedupe_key: nil, details: {}, occurred_at: Time.current)
          expected_decimal = expected.to_d
          actual_decimal = actual.to_d
          raise ArgumentError, "tolerance must be non-negative" if tolerance.to_d.negative?
          if materiality_threshold.present? && materiality_threshold.to_d < tolerance.to_d
            raise ArgumentError, "materiality threshold must be greater than or equal to tolerance"
          end
          difference = actual_decimal - expected_decimal
          absolute_difference = difference.abs
          tolerance_decimal = tolerance.to_d
          materiality = (materiality_threshold || tolerance).to_d

          status =
            if absolute_difference <= tolerance_decimal
              "passed"
            elsif absolute_difference > materiality
              "failed"
            else
              "warning"
            end

          ReconciliationEvent.record_once!(
            family: family,
            account: account,
            account_provider: account_provider,
            subject: subject,
            raw_source_record: raw_source_record,
            kind: kind,
            status: status,
            expected: { "value" => expected_decimal.to_s("F") },
            actual: { "value" => actual_decimal.to_s("F") },
            difference: { "value" => difference.to_s("F"), "absolute" => absolute_difference.to_s("F") },
            material: status == "failed",
            tolerance: tolerance_decimal,
            currency: currency,
            dedupe_key: dedupe_key,
            details: details,
            occurred_at: occurred_at
          )
        end
      end
    end
  end
end

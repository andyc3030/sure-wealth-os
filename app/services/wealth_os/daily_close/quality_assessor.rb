# frozen_string_literal: true

module WealthOs
  module DailyClose
    class QualityAssessor
      Result = Data.define(:status, :confidence, :details) do
        def fail?
          status == "fail"
        end

        def as_json(*)
          {
            "status" => status,
            "confidence" => confidence.to_s("F"),
            "details" => details
          }
        end
      end

      def initialize(family:, close_date:, cutoff_at:, fx_resolver:)
        @family = family
        @close_date = close_date.to_date
        @cutoff_at = cutoff_at
        @fx_resolver = fx_resolver
      end

      def call
        zone = cutoff_at.time_zone
        day_start = zone.local(close_date.year, close_date.month, close_date.day).beginning_of_day
        reconciliation = ReconciliationEvent.where(
          family_id: family.id,
          occurred_at: day_start..cutoff_at
        )
        conflicts = SourceConflict.where(family_id: family.id, status: "open")

        details = {
          "open_source_conflicts" => conflicts.count,
          "material_open_source_conflicts" =>
            conflicts.where("impact_amount IS NOT NULL AND impact_amount <> 0").count,
          "failed_reconciliations" => reconciliation.where(status: "failed").count,
          "material_failed_reconciliations" =>
            reconciliation.where(status: "failed", material: true).count,
          "reconciliation_warnings" => reconciliation.where(status: "warning").count,
          "failed_or_stale_syncs" =>
            Sync.for_family(family).where(created_at: day_start..cutoff_at, status: %w[failed stale]).count,
          "stale_fx_rates" => fx_resolver.resolutions.uniq { |rate|
            [ rate.from_currency, rate.to_currency, rate.requested_date ]
          }.count(&:stale?)
        }

        status = if details.fetch("material_open_source_conflicts").positive? ||
                    details.fetch("material_failed_reconciliations").positive? ||
                    details.fetch("failed_or_stale_syncs").positive?
          "fail"
        elsif details.fetch("open_source_conflicts").positive? ||
              details.fetch("failed_reconciliations").positive? ||
              details.fetch("reconciliation_warnings").positive? ||
              details.fetch("stale_fx_rates").positive?
          "warning"
        else
          "pass"
        end

        confidence = case status
        when "pass" then BigDecimal("1")
        when "warning" then BigDecimal("0.75")
        else BigDecimal("0.25")
        end

        Result.new(status, confidence, details.freeze)
      end

      private

        attr_reader :family, :close_date, :cutoff_at, :fx_resolver
    end
  end
end

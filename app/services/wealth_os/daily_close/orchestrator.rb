# frozen_string_literal: true

module WealthOs
  module DailyClose
    class Orchestrator
      CutoffNotReached = Class.new(StandardError)
      SyncInProgress = Class.new(StandardError)

      class QualityGateFailed < StandardError
        attr_reader :quality, :action_now

        def initialize(quality:, action_now:)
          @quality = quality
          @action_now = action_now
          super("daily close blocked by material data-quality failures")
        end
      end

      def self.call(family:, close_date: nil, now: Time.current,
                    timezone: Configuration::DEFAULT_TIMEZONE,
                    reporting_currency: Configuration::DEFAULT_REPORTING_CURRENCY)
        new(
          family: family,
          close_date: close_date,
          now: now,
          timezone: timezone,
          reporting_currency: reporting_currency
        ).call
      end

      def initialize(family:, close_date:, now:, timezone:, reporting_currency:)
        @family = family
        @now = now
        @timezone = timezone
        @reporting_currency = reporting_currency.to_s.upcase
        @close_date = (close_date || Configuration.eligible_close_date(
          now: now,
          timezone: timezone
        )).to_date
      end

      def call
        cutoff_at = Configuration.cutoff_at(close_date, timezone: timezone)
        raise CutoffNotReached, "daily close cut-off has not been reached" if now < cutoff_at
        raise SyncInProgress, "provider/account sync is still in progress" if Sync.any_incomplete_for?(family)

        fx_resolver = FxResolver.new
        valuation = ValuationBuilder.new(
          family: family,
          close_date: close_date,
          reporting_currency: reporting_currency,
          fx_resolver: fx_resolver
        ).call
        ledger = LedgerBuilder.new(
          family: family,
          close_date: close_date,
          reporting_currency: reporting_currency,
          fx_resolver: fx_resolver
        ).call
        performance = PerformanceBuilder.new(
          family: family,
          close_date: close_date,
          valuation: valuation,
          ledger: ledger
        ).call
        forecast = ForecastBuilder.new(
          family: family,
          close_date: close_date,
          reporting_currency: reporting_currency,
          fx_resolver: fx_resolver
        ).call
        income_risk = IncomeRiskBuilder.new(
          family: family,
          close_date: close_date,
          reporting_currency: reporting_currency,
          fx_resolver: fx_resolver,
          forecast: forecast
        ).call
        quality = QualityAssessor.new(
          family: family,
          close_date: close_date,
          cutoff_at: cutoff_at,
          fx_resolver: fx_resolver
        ).call
        action_now = ActionNowBuilder.call(quality: quality, forecast: forecast)

        raise QualityGateFailed.new(quality: quality, action_now: action_now) if quality.fail?

        provenance = ProvenanceManifestBuilder.new(
          family: family,
          close_date: close_date,
          cutoff_at: cutoff_at,
          valuation: valuation
        ).call

        payload = {
          "schema_version" => 2,
          "close_date" => close_date.iso8601,
          "cutoff_at" => cutoff_at.iso8601,
          "timezone" => timezone,
          "reporting_currency" => reporting_currency,
          "pipeline" => pipeline_evidence(cutoff_at: cutoff_at, quality: quality),
          "valuation" => valuation.as_json,
          "income_and_liabilities" => ledger.as_json,
          "performance" => performance,
          "forecast" => forecast.as_json,
          "income_risk" => income_risk.as_json,
          "quality" => quality.as_json,
          "provenance" => provenance,
          "action_now" => action_now
        }

        DailyCloseSnapshot.capture!(
          family: family,
          close_date: close_date,
          cutoff_at: cutoff_at,
          closed_at: now,
          timezone: timezone,
          reporting_currency: reporting_currency,
          quality_status: quality.status,
          confidence: quality.confidence,
          gross_assets: valuation.gross_assets,
          total_liabilities: valuation.total_liabilities,
          net_worth: valuation.net_worth,
          payload: payload,
          schema_version: 2
        )
      end

      private

        attr_reader :family, :close_date, :now, :timezone, :reporting_currency

        def pipeline_evidence(cutoff_at:, quality:)
          {
            "sync" => { "status" => "settled", "incomplete_syncs" => 0 },
            "raw_ingest" => {
              "raw_source_records" =>
                RawSourceRecord.where(family_id: family.id).where("observed_at <= ?", cutoff_at).count
            },
            "normalize" => {
              "entries_through_close" => family.entries.where(date: ..close_date).count,
              "holdings_through_close" => family.holdings.where(date: ..close_date).count
            },
            "reconcile" => quality.details,
            "value" => { "status" => "complete" },
            "income_liabilities" => { "status" => "complete" },
            "performance" => { "status" => "complete" },
            "forecast" => { "status" => "complete" },
            "income_risk" => { "status" => "complete", "model" => "deterministic_income_stress" },
            "quality" => { "status" => quality.status },
            "snapshot" => { "status" => "immutable" },
            "action_now" => { "status" => "deterministic" }
          }
        end
    end
  end
end

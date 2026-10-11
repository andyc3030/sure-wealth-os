# frozen_string_literal: true

module WealthOs
  module DailyClose
    class ProvenanceManifestBuilder
      def initialize(family:, close_date:, cutoff_at:, valuation:)
        @family = family
        @close_date = close_date.to_date
        @cutoff_at = cutoff_at
        @valuation = valuation
      end

      def call
        income = income_events
        actual_liabilities = actual_liability_payments
        scheduled_liabilities = scheduled_liability_payments
        reconciliation = reconciliation_rows

        raw_ids = (
          income.filter_map { |row| row["raw_source_record_id"] } +
          actual_liabilities.filter_map { |row| row["raw_source_record_id"] } +
          scheduled_liabilities.filter_map { |row| row["raw_source_record_id"] } +
          reconciliation.filter_map { |row| row["raw_source_record_id"] }
        ).uniq.sort

        {
          "captured_at_cutoff" => cutoff_at.iso8601,
          "valuation_accounts" => valuation.accounts,
          "income_events" => income,
          "actual_liability_payments" => actual_liabilities,
          "scheduled_liability_payments" => scheduled_liabilities,
          "quality" => {
            "source_conflicts" => conflict_rows,
            "reconciliation_events" => reconciliation,
            "syncs" => sync_rows
          },
          "raw_source_record_ids" => raw_ids,
          "previous_snapshot_id" => previous_snapshot&.id
        }
      end

      private
        attr_reader :family, :close_date, :cutoff_at, :valuation

        def income_events
          IncomeEvent.where(family_id: family.id).order(:canonical_key, :id).map do |event|
            {
              "id" => event.id, "canonical_key" => event.canonical_key, "state" => event.state,
              "income_type" => event.income_type, "account_id" => event.account_id,
              "security_id" => event.security_id, "raw_source_record_id" => event.raw_source_record_id,
              "currency" => event.currency, "net_amount" => event.net_amount.to_s("F"),
              "expected_on" => event.expected_on&.iso8601,
              "accrual_end_date" => event.accrual_end_date&.iso8601,
              "payable_on" => event.payable_on&.iso8601,
              "received_on" => event.received_on&.iso8601,
              "confidence" => event.confidence, "source_system" => event.source_system,
              "source_key" => event.source_key
            }
          end
        end

        def actual_liability_payments
          liability_rows(LiabilityPayment.where(
            family_id: family.id, payment_type: "actual", payment_date: close_date
          ))
        end

        def scheduled_liability_payments
          liability_rows(LiabilityPayment.where(
            family_id: family.id, payment_type: "scheduled",
            payment_date: (close_date + 1.day)..(close_date + 365.days)
          ))
        end

        def liability_rows(scope)
          scope.order(:payment_date, :canonical_key, :id).map do |payment|
            {
              "id" => payment.id, "canonical_key" => payment.canonical_key,
              "account_id" => payment.account_id, "entry_id" => payment.entry_id,
              "raw_source_record_id" => payment.raw_source_record_id,
              "payment_date" => payment.payment_date.iso8601, "payment_type" => payment.payment_type,
              "currency" => payment.currency, "total_amount" => payment.total_amount.to_d.to_s("F"),
              "principal_amount" => payment.principal_amount.to_d.to_s("F"),
              "financing_cost_amount" => payment.financing_cost_amount.to_s("F"),
              "insurance_amount" => payment.insurance_amount.to_d.to_s("F"),
              "source_system" => payment.source_system, "source_key" => payment.source_key
            }
          end
        end

        def reconciliation_rows
          ReconciliationEvent.where(family_id: family.id, occurred_at: day_start..cutoff_at)
            .order(:occurred_at, :id).map do |event|
              {
                "id" => event.id, "kind" => event.kind, "status" => event.status,
                "material" => event.material, "account_id" => event.account_id,
                "raw_source_record_id" => event.raw_source_record_id, "currency" => event.currency,
                "occurred_at" => event.occurred_at.iso8601
              }
            end
        end

        def conflict_rows
          SourceConflict.where(family_id: family.id).where("detected_at <= ?", cutoff_at)
            .order(:detected_at, :id).map do |conflict|
              {
                "id" => conflict.id, "field_name" => conflict.field_name, "status" => conflict.status,
                "account_id" => conflict.account_id, "source_record_a_id" => conflict.source_record_a_id,
                "source_record_b_id" => conflict.source_record_b_id,
                "selected_source_record_id" => conflict.selected_source_record_id,
                "impact_amount" => conflict.impact_amount&.to_d&.to_s("F"),
                "currency" => conflict.currency, "detected_at" => conflict.detected_at.iso8601,
                "resolved_at" => conflict.resolved_at&.iso8601
              }
            end
        end

        def sync_rows
          Sync.for_family(family).where(created_at: day_start..cutoff_at).order(:created_at, :id).map do |sync|
            {
              "id" => sync.id, "syncable_type" => sync.syncable_type,
              "syncable_id" => sync.syncable_id, "status" => sync.status,
              "created_at" => sync.created_at.iso8601,
              "completed_at" => sync.completed_at&.iso8601,
              "failed_at" => sync.failed_at&.iso8601
            }
          end
        end

        def day_start
          @day_start ||= begin
            zone = cutoff_at.time_zone
            zone.local(close_date.year, close_date.month, close_date.day).beginning_of_day
          end
        end

        def previous_snapshot
          @previous_snapshot ||= DailyCloseSnapshot.where(family_id: family.id)
            .where("close_date < ?", close_date).order(close_date: :desc).first
        end
    end
  end
end

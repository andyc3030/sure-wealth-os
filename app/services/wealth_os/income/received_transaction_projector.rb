# frozen_string_literal: true

module WealthOs
  module Income
    class ReceivedTransactionProjector
      LABEL_TO_TYPE = {
        "Dividend" => "dividend",
        "Interest" => "interest"
      }.freeze

      class << self
        def call(entry)
          transaction = entry&.entryable
          return nil unless transaction.is_a?(Transaction)
          return nil if transaction.pending?

          income_type = LABEL_TO_TYPE[transaction.investment_activity_label]
          return nil unless income_type

          canonical_key = [
            "booked",
            entry.account_id,
            entry.source.presence || "manual",
            entry.external_id.presence || entry.id,
            income_type
          ].join(":")

          cash = entry.amount.to_d.abs
          common = {
            gross_amount: cash,
            cash_received_amount: cash,
            currency: entry.currency,
            expected_on: entry.date,
            received_on: entry.date,
            confidence: "confirmed",
            source_system: entry.source,
            source_key: entry.external_id,
            metadata: {
              "method" => "booked_transaction",
              "gross_amount_basis" => "cash_received_when_provider_gross_unknown"
            }
          }

          event = IncomeEvent.find_by(family: entry.account.family, canonical_key: canonical_key)

          if event
            return event if equivalent_received?(event, common)

            event.transition_to!(
              "received",
              attributes: common.merge(raw_source_record_id: entry.raw_source_record_id),
              reason: "booked provider income transaction",
              raw_source_record: entry.raw_source_record
            )
            return event
          end

          IncomeEvent.create!(
            family: entry.account.family,
            account: entry.account,
            security: transaction.activity_security,
            raw_source_record: entry.raw_source_record,
            canonical_key: canonical_key,
            income_type: income_type,
            state: "received",
            **common
          )
        end

        private

          def equivalent_received?(event, attrs)
            event.received? &&
              event.gross_amount.to_d == attrs.fetch(:gross_amount).to_d &&
              event.cash_received_amount.to_d == attrs.fetch(:cash_received_amount).to_d &&
              event.received_on == attrs.fetch(:received_on) &&
              event.currency == attrs.fetch(:currency)
          end
      end
    end
  end
end

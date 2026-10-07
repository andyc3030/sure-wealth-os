# frozen_string_literal: true

module WealthOs
  module Income
    class ReceivedTransactionProjector
      LABEL_TO_TYPE = {
        "Dividend" => "dividend",
        "Interest" => "interest"
      }.freeze

      def self.call(entry)
        transaction = entry&.entryable
        return nil unless transaction.is_a?(Transaction)
        return nil if transaction.pending?

        income_type = LABEL_TO_TYPE[transaction.investment_activity_label]
        return nil unless income_type
        return nil unless entry.amount.to_d.negative?

        # The canonical Entry id is stable across provider re-sync and
        # pending→posted reconciliation. Do not key received income to a
        # provider external id that may change after the Entry is claimed.
        event_key = [ "entry", entry.id, income_type ].join(":")

        source_system = entry.source.presence || "manual"
        attrs = {
          account: entry.account,
          entry: entry,
          cash_amount: entry.amount.to_d.abs,
          effective_date: entry.date,
          payable_on: entry.date,
          source_system: source_system,
          method: "booked_transaction_cash_only",
          confidence: "confirmed"
        }
        attrs[:security] = transaction.activity_security if transaction.activity_security.present?
        attrs[:raw_source_record] = entry.raw_source_record if entry.raw_source_record.present?

        current = IncomeEvent.current_for(family: entry.account.family, event_key: event_key)
        if current
          expected_security_id = attrs.key?(:security) ? attrs[:security]&.id : current.security_id
          expected_raw_source_id = attrs.key?(:raw_source_record) ? attrs[:raw_source_record]&.id : current.raw_source_record_id

          unchanged = current.state == "received" &&
                      current.account_id == attrs[:account].id &&
                      current.security_id == expected_security_id &&
                      current.entry_id == entry.id &&
                      current.raw_source_record_id == expected_raw_source_id &&
                      current.cash_amount.to_d == attrs[:cash_amount] &&
                      current.effective_date == attrs[:effective_date] &&
                      current.source_system == attrs[:source_system] &&
                      current.method == attrs[:method] &&
                      current.confidence == attrs[:confidence]
          return current if unchanged

          return current.transition_to!("received", **attrs)
        end

        IncomeEvent.create!(
          family: entry.account.family,
          event_key: event_key,
          income_type: income_type,
          state: "received",
          amount: nil,
          tax_withheld: nil,
          fees: nil,
          currency: entry.currency,
          **attrs
        )
      end
    end
  end
end

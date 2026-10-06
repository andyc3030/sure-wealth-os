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

        event_key = [
          entry.source.presence || "manual",
          entry.external_id.presence || entry.id,
          income_type
        ].join(":")

        attrs = {
          account: entry.account,
          security: transaction.activity_security,
          raw_source_record: entry.raw_source_record,
          state: "received",
          amount: entry.amount.to_d.abs,
          cash_amount: entry.amount.to_d.abs,
          currency: entry.currency,
          effective_date: entry.date,
          payable_on: entry.date,
          source_system: entry.source,
          method: "booked_transaction",
          confidence: "confirmed"
        }

        current = IncomeEvent.current_for(family: entry.account.family, event_key: event_key)
        if current
          return current if current.state == "received" &&
                            current.amount.to_d == attrs[:amount] &&
                            current.cash_amount.to_d == attrs[:cash_amount] &&
                            current.effective_date == attrs[:effective_date]

          return current.transition_to!("received", **attrs)
        end

        IncomeEvent.create!(
          family: entry.account.family,
          event_key: event_key,
          income_type: income_type,
          **attrs
        )
      end
    end
  end
end

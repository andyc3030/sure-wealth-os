# frozen_string_literal: true

module WealthOs
  module Income
    class StateSummary
      Result = Data.define(:currency, :forecast, :accrued, :declared, :received) do
        def total
          forecast + accrued + declared + received
        end

        def [](state)
          public_send(state)
        end
      end

      def self.call(events)
        grouped = Array(events).group_by(&:currency)

        grouped.transform_values do |currency_events|
          currency = currency_events.first.currency
          values = IncomeEvent::STATES.to_h do |state|
            amount = currency_events.select { |event| event.state == state }.sum(BigDecimal("0"), &:net_amount)
            [ state, amount ]
          end

          Result.new(
            currency,
            values.fetch("forecast"),
            values.fetch("accrued"),
            values.fetch("declared"),
            values.fetch("received")
          )
        end
      end
    end
  end
end

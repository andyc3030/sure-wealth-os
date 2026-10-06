# frozen_string_literal: true

module WealthOs
  module Income
    class LifecycleSummary
      STATES = IncomeEvent::STATES.freeze

      def initialize(scope)
        @scope = scope
      end

      # Returns native-currency totals. FX conversion belongs to the valuation
      # layer so this engine never silently invents a rate.
      def call
        totals = Hash.new do |currencies, currency|
          currencies[currency] = STATES.index_with { BigDecimal("0") }
            .merge("received_cash" => BigDecimal("0"))
        end

        @scope.current.find_each do |event|
          totals[event.currency][event.state] += event.amount.to_d
          totals[event.currency]["received_cash"] += event.received_cash
        end

        totals
      end
    end
  end
end

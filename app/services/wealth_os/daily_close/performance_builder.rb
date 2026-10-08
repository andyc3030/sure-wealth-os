# frozen_string_literal: true

module WealthOs
  module DailyClose
    class PerformanceBuilder
      def initialize(family:, close_date:, valuation:, ledger:)
        @family = family
        @close_date = close_date.to_date
        @valuation = valuation
        @ledger = ledger
      end

      def call
        previous = DailyCloseSnapshot
          .where(family_id: family.id)
          .where("close_date < ?", close_date)
          .order(close_date: :desc)
          .first

        return {
          "available" => false,
          "reason" => "no_previous_authoritative_close",
          "twr" => nil,
          "mwr" => nil
        } unless previous

        components = {
          "received_income" => ledger.received_cash_today,
          "financing_cost" => -ledger.financing_cost_today,
          "insurance_cost" => -ledger.insurance_paid_today
        }

        bridge = WealthOs::Performance::NetWorthAttribution.call(
          opening_net_worth: previous.net_worth,
          closing_net_worth: valuation.net_worth,
          components: components
        )

        {
          "available" => true,
          "opening_close_date" => previous.close_date.iso8601,
          "opening_net_worth" => bridge.opening_net_worth.to_s("F"),
          "closing_net_worth" => bridge.closing_net_worth.to_s("F"),
          "actual_change" => bridge.actual_change.to_s("F"),
          "known_components" => components.transform_values { |value| value.to_d.to_s("F") },
          "known_component_total" => bridge.explained_change.to_s("F"),
          "unexplained_residual" => bridge.residual.to_s("F"),
          "twr" => nil,
          "mwr" => nil,
          "return_note" => "TWR/MWR are not inferred from net-worth snapshots without exact external-flow boundaries"
        }
      end

      private

        attr_reader :family, :close_date, :valuation, :ledger
    end
  end
end

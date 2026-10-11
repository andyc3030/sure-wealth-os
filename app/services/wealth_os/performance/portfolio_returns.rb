# frozen_string_literal: true

module WealthOs
  module Performance
    class PortfolioReturns
      Result = Data.define(:time_weighted_return, :money_weighted_return, :money_weighted_ambiguous)

      def self.call(twr_subperiods:, xirr_flows:)
        xirr = Portfolio::Xirr.new(xirr_flows)

        Result.new(
          Portfolio::Twr.rate(twr_subperiods),
          xirr.rate,
          xirr.ambiguous?
        )
      end
    end
  end
end

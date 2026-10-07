# frozen_string_literal: true

module WealthOs
  module Performance
    class NetWorthAttribution
      Result = Data.define(:opening_net_worth, :closing_net_worth, :components, :actual_change, :explained_change, :residual, :tolerance) do
        def reconciled?
          residual.abs <= tolerance
        end
      end

      def self.call(opening_net_worth:, closing_net_worth:, components:, tolerance: 0)
        opening = opening_net_worth.to_d
        closing = closing_net_worth.to_d
        tolerance = tolerance.to_d
        raise ArgumentError, "tolerance must be non-negative" if tolerance.negative?

        normalized = components.to_h.transform_keys(&:to_s).transform_values(&:to_d).freeze
        actual_change = closing - opening
        explained_change = normalized.values.sum(BigDecimal("0"))
        residual = actual_change - explained_change

        Result.new(opening, closing, normalized, actual_change, explained_change, residual, tolerance)
      end
    end
  end
end

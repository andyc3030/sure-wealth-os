# frozen_string_literal: true

module WealthOs
  module Performance
    class FxAttribution
      Result = Data.define(
        :opening_reporting_value,
        :closing_reporting_value,
        :local_market_effect,
        :fx_effect,
        :total_change
      )

      def self.call(opening_local:, closing_local:, opening_fx:, closing_fx:)
        opening_local = opening_local.to_d
        closing_local = closing_local.to_d
        opening_fx = opening_fx.to_d
        closing_fx = closing_fx.to_d

        raise ArgumentError, "FX rates must be positive" unless opening_fx.positive? && closing_fx.positive?

        opening_reporting = opening_local * opening_fx
        closing_reporting = closing_local * closing_fx
        local_market_effect = (closing_local - opening_local) * opening_fx
        fx_effect = closing_local * (closing_fx - opening_fx)
        total_change = closing_reporting - opening_reporting

        Result.new(
          opening_reporting,
          closing_reporting,
          local_market_effect,
          fx_effect,
          total_change
        )
      end
    end
  end
end

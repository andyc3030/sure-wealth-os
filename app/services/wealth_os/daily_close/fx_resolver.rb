# frozen_string_literal: true

module WealthOs
  module DailyClose
    class FxResolver
      MissingRateError = Class.new(StandardError)
      LOOKBACK_DAYS = 5

      Resolution = Data.define(
        :from_currency, :to_currency, :rate, :rate_date, :requested_date, :age_days, :source
      ) do
        def stale?
          age_days.positive?
        end

        def as_json(*)
          {
            "from_currency" => from_currency,
            "to_currency" => to_currency,
            "rate" => rate.to_s("F"),
            "rate_date" => rate_date.iso8601,
            "requested_date" => requested_date.iso8601,
            "age_days" => age_days,
            "source" => source
          }
        end
      end

      attr_reader :resolutions

      def initialize
        @cache = {}
        @resolutions = []
      end

      def resolve(from:, to:, date:)
        from = from.to_s.upcase
        to = to.to_s.upcase
        date = date.to_date
        key = [ from, to, date ]
        return @cache.fetch(key) if @cache.key?(key)

        resolution = if from == to
          Resolution.new(from, to, BigDecimal("1"), date, date, 0, "identity")
        else
          resolve_market_rate(from: from, to: to, date: date)
        end

        @resolutions << resolution
        @cache[key] = resolution
      end

      private

        def resolve_market_rate(from:, to:, date:)
          direct = nearest_rate(from: from, to: to, date: date)
          if direct
            return build_resolution(
              from: from,
              to: to,
              requested_date: date,
              rate: direct.rate.to_d,
              rate_date: direct.date,
              source: "exchange_rate"
            )
          end

          inverse = nearest_rate(from: to, to: from, date: date)
          if inverse
            inverse_rate = inverse.rate.to_d
            raise MissingRateError, "invalid zero FX rate for #{to}/#{from}" unless inverse_rate.positive?

            return build_resolution(
              from: from,
              to: to,
              requested_date: date,
              rate: BigDecimal("1") / inverse_rate,
              rate_date: inverse.date,
              source: "inverse_exchange_rate"
            )
          end

          raise MissingRateError,
                "no normalized FX rate for #{from}/#{to} within #{LOOKBACK_DAYS} days of #{date}"
        end

        def nearest_rate(from:, to:, date:)
          ExchangeRate
            .where(from_currency: from, to_currency: to, date: (date - LOOKBACK_DAYS.days)..date)
            .order(date: :desc)
            .first
        end

        def build_resolution(from:, to:, requested_date:, rate:, rate_date:, source:)
          raise MissingRateError, "FX rate must be positive for #{from}/#{to}" unless rate.positive?

          Resolution.new(
            from,
            to,
            rate,
            rate_date,
            requested_date,
            (requested_date - rate_date).to_i,
            source
          )
        end
    end
  end
end

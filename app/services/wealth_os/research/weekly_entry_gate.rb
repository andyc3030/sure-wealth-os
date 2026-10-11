# frozen_string_literal: true

module WealthOs
  module Research
    class WeeklyEntryGate
      def self.call(open:, close:, sma_10w:, sma_50w:, sma_250w:, near_10w_tolerance_pct:, bar_closed_at:)
        return insufficient("near-10W tolerance must be configured") if near_10w_tolerance_pct.blank?
        return insufficient("weekly bar close timestamp is required") if bar_closed_at.blank?

        closed_at = bar_closed_at.in_time_zone("America/New_York")
        return insufficient("bar is not a completed Friday New York weekly close") unless closed_at.friday?

        values = [ open, close, sma_10w, sma_50w, sma_250w, near_10w_tolerance_pct ]
        return insufficient("weekly price/SMA inputs are incomplete") if values.any?(&:nil?)

        open_d, close_d, sma10_d, sma50_d, sma250_d, tolerance_d = values.map(&:to_d)
        return insufficient("moving averages and tolerance must be positive") if [ sma10_d, sma50_d, sma250_d ].any?(&:zero?) || tolerance_d.negative?

        reclaim_50w = open_d < sma50_d && close_d > sma50_d
        above_250w = close_d > sma250_d
        distance_10w_pct = ((close_d - sma10_d).abs / sma10_d * 100).round(4)
        near_10w = distance_10w_pct <= tolerance_d
        passed = reclaim_50w && above_250w && near_10w

        {
          status: passed ? "pass" : "fail",
          reclaim_50w: reclaim_50w,
          above_250w: above_250w,
          near_10w: near_10w,
          distance_10w_pct: distance_10w_pct.to_s("F"),
          tolerance_pct: tolerance_d.to_s("F"),
          bar_closed_at_new_york: closed_at.iso8601,
          advisory_only: true
        }
      end

      def self.insufficient(reason)
        {
          status: "insufficient_evidence",
          reason: reason,
          advisory_only: true
        }
      end
      private_class_method :insufficient
    end
  end
end

# frozen_string_literal: true

module WealthOs
  module DailyClose
    module Configuration
      DEFAULT_TIMEZONE = "Europe/London"
      DEFAULT_REPORTING_CURRENCY = "GBP"
      CUTOFF_HOUR = 23
      CUTOFF_MINUTE = 59

      module_function

      def cutoff_at(date, timezone: DEFAULT_TIMEZONE)
        zone = zone!(timezone)
        date = date.to_date
        zone.local(date.year, date.month, date.day, CUTOFF_HOUR, CUTOFF_MINUTE)
      end

      def eligible_close_date(now: Time.current, timezone: DEFAULT_TIMEZONE)
        zone = zone!(timezone)
        local_now = now.in_time_zone(zone)
        today = local_now.to_date

        local_now >= cutoff_at(today, timezone: timezone) ? today : today - 1.day
      end

      def zone!(timezone)
        ActiveSupport::TimeZone[timezone] ||
          raise(ArgumentError, "unknown daily-close timezone: #{timezone}")
      end
    end
  end
end

# frozen_string_literal: true

require "test_helper"

class WealthOs::DailyClose::ConfigurationTest < ActiveSupport::TestCase
  test "London cut-off is DST aware" do
    date = Date.new(2026, 6, 1)
    cutoff = WealthOs::DailyClose::Configuration.cutoff_at(date)

    assert_equal "Europe/London", cutoff.time_zone.name
    assert_equal 23, cutoff.hour
    assert_equal 59, cutoff.min
    assert_equal 3600, cutoff.utc_offset
  end

  test "eligible close date does not close the current day before 23:59 London" do
    before_cutoff = Time.utc(2026, 6, 1, 22, 58)
    at_cutoff = Time.utc(2026, 6, 1, 22, 59)

    assert_equal Date.new(2026, 5, 31),
                 WealthOs::DailyClose::Configuration.eligible_close_date(now: before_cutoff)
    assert_equal Date.new(2026, 6, 1),
                 WealthOs::DailyClose::Configuration.eligible_close_date(now: at_cutoff)
  end
end

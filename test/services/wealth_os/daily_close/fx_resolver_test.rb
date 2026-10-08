# frozen_string_literal: true

require "test_helper"

class WealthOs::DailyClose::FxResolverTest < ActiveSupport::TestCase
  test "uses the nearest normalized prior rate and exposes staleness" do
    ExchangeRate.where(
      from_currency: "CHF",
      to_currency: "GBP",
      date: Date.new(2026, 10, 7)
    ).delete_all
    ExchangeRate.create!(
      from_currency: "CHF",
      to_currency: "GBP",
      date: Date.new(2026, 10, 7),
      rate: BigDecimal("0.81")
    )

    result = WealthOs::DailyClose::FxResolver.new.resolve(
      from: "CHF",
      to: "GBP",
      date: Date.new(2026, 10, 8)
    )

    assert_equal BigDecimal("0.81"), result.rate
    assert_equal 1, result.age_days
    assert result.stale?
  end

  test "never silently substitutes one for a missing cross-currency rate" do
    assert_raises(WealthOs::DailyClose::FxResolver::MissingRateError) do
      WealthOs::DailyClose::FxResolver.new.resolve(
        from: "ZAR",
        to: "GBP",
        date: Date.new(1999, 1, 1)
      )
    end
  end
end

# frozen_string_literal: true

require "test_helper"

class WealthOs::DailyClose::LedgerBuilderTest < ActiveSupport::TestCase
  setup do
    @family = families(:dylan_family)
    @close_date = Date.new(2026, 10, 15)
    @resolver = WealthOs::DailyClose::FxResolver.new

    add_rate(@close_date, "0.8")
    add_rate(Date.new(2026, 10, 1), "0.7")
    add_rate(Date.new(2026, 1, 10), "0.6")
    add_rate(Date.new(2025, 12, 1), "0.5")
    add_rate(Date.new(2025, 10, 15), "0.4")
  end

  test "captures received income today MTD YTD and TTM using receipt-date FX" do
    received("today", 100, @close_date)
    received("month", 50, Date.new(2026, 10, 1))
    received("year", 25, Date.new(2026, 1, 10))
    received("ttm", 10, Date.new(2025, 12, 1))
    received("outside-ttm", 1_000, Date.new(2025, 10, 15))

    result = build

    assert_equal BigDecimal("80"), result.received_cash_today
    assert_equal BigDecimal("115"), result.received_cash_mtd
    assert_equal BigDecimal("130"), result.received_cash_ytd
    assert_equal BigDecimal("135"), result.received_cash_ttm

    payload = result.as_json
    assert_equal "80.0", payload.fetch("received_cash_today")
    assert_equal "115.0", payload.fetch("received_cash_mtd")
    assert_equal "130.0", payload.fetch("received_cash_ytd")
    assert_equal "135.0", payload.fetch("received_cash_ttm")
  end

  test "future received dates do not leak into close windows" do
    received("future", 100, @close_date + 1.day)
    result = build

    assert_equal BigDecimal("0"), result.received_cash_today
    assert_equal BigDecimal("0"), result.received_cash_mtd
    assert_equal BigDecimal("0"), result.received_cash_ytd
    assert_equal BigDecimal("0"), result.received_cash_ttm
  end

  private

    def build
      WealthOs::DailyClose::LedgerBuilder.new(
        family: @family,
        close_date: @close_date,
        reporting_currency: "GBP",
        fx_resolver: @resolver
      ).call
    end

    def received(key, amount, date)
      IncomeEvent.create!(
        family: @family,
        canonical_key: "ledger-window-#{key}",
        state: "received",
        income_type: "interest",
        currency: "USD",
        gross_amount: amount,
        withholding_tax_amount: 0,
        fee_amount: 0,
        cash_received_amount: amount,
        received_on: date,
        confidence: "confirmed"
      )
    end

    def add_rate(date, rate)
      ExchangeRate.where(from_currency: "USD", to_currency: "GBP", date: date).delete_all
      ExchangeRate.create!(from_currency: "USD", to_currency: "GBP", date: date, rate: BigDecimal(rate))
    end
end

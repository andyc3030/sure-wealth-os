# frozen_string_literal: true

require "test_helper"

class WealthOs::DailyClose::ValuationBuilderTest < ActiveSupport::TestCase
  test "values exact-date balances into reporting currency without silent fallback" do
    family = families(:dylan_family)
    account = accounts(:depository)
    family.accounts.where.not(id: account.id).update_all(status: "disabled")

    date = Date.new(2026, 10, 8)
    account.balances.where(date: date).delete_all
    account.balances.create!(
      date: date,
      currency: "USD",
      balance: 5_000,
      cash_balance: 5_000,
      start_cash_balance: 5_000,
      start_non_cash_balance: 0
    )
    ExchangeRate.where(from_currency: "USD", to_currency: "GBP", date: date).delete_all
    ExchangeRate.create!(
      from_currency: "USD",
      to_currency: "GBP",
      date: date,
      rate: BigDecimal("0.8")
    )

    result = WealthOs::DailyClose::ValuationBuilder.new(
      family: family,
      close_date: date,
      reporting_currency: "GBP",
      fx_resolver: WealthOs::DailyClose::FxResolver.new
    ).call

    assert_equal BigDecimal("4000"), result.gross_assets
    assert_equal BigDecimal("0"), result.total_liabilities
    assert_equal BigDecimal("4000"), result.net_worth
  end
end

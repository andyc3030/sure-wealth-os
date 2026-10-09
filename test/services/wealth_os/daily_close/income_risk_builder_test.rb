# frozen_string_literal: true

require "test_helper"

class WealthOs::DailyClose::IncomeRiskBuilderTest < ActiveSupport::TestCase
  setup do
    @family = families(:dylan_family)
    @date = Date.new(2026, 10, 8)
    @resolver = WealthOs::DailyClose::FxResolver.new
    IncomeEvent.where(family_id: @family.id).delete_all
  end

  test "calculates deterministic 365 day income stress and concentration" do
    IncomeEvent.create!(
      family: @family,
      account: accounts(:investment),
      security: securities(:aapl),
      canonical_key: "declared-confirmed",
      state: "declared",
      income_type: "dividend",
      gross_amount: 100,
      currency: "GBP",
      declared_on: @date,
      payable_on: @date + 30.days,
      confidence: "confirmed"
    )
    IncomeEvent.create!(
      family: @family,
      account: accounts(:depository),
      canonical_key: "forecast-estimated",
      state: "forecast",
      income_type: "interest",
      gross_amount: 100,
      currency: "GBP",
      expected_on: @date + 60.days,
      confidence: "estimated"
    )
    IncomeEvent.create!(
      family: @family,
      canonical_key: "undated-low",
      state: "forecast",
      income_type: "other",
      gross_amount: 40,
      currency: "GBP",
      confidence: "low"
    )

    result = build(liabilities: 50)

    assert_equal BigDecimal("200"), result.baseline_income
    assert_equal BigDecimal("152.5"), result.stressed_income
    assert_equal BigDecimal("47.5"), result.income_at_risk
    assert_equal BigDecimal("0.7625"), result.sustainability_ratio
    assert_equal BigDecimal("102.5"), result.stressed_net_cash
    assert_equal 1, result.undated_income_count
    assert_equal BigDecimal("40"), result.undated_income_amount
    assert_equal BigDecimal("0.5"), result.top_source_share
    assert_equal BigDecimal("0.5"), result.concentration_hhi
    assert_equal false, result.as_json.fetch("statistical_var")
  end

  test "excludes past and beyond-horizon income and leaves zero-income ratio unavailable" do
    IncomeEvent.create!(
      family: @family,
      canonical_key: "past",
      state: "forecast",
      income_type: "interest",
      gross_amount: 100,
      currency: "GBP",
      expected_on: @date,
      confidence: "confirmed"
    )
    IncomeEvent.create!(
      family: @family,
      canonical_key: "future",
      state: "forecast",
      income_type: "interest",
      gross_amount: 100,
      currency: "GBP",
      expected_on: @date + 366.days,
      confidence: "confirmed"
    )

    result = build(liabilities: 25)

    assert_equal BigDecimal("0"), result.baseline_income
    assert_equal BigDecimal("0"), result.income_at_risk
    assert_nil result.sustainability_ratio
    assert_nil result.top_source_share
    assert_equal BigDecimal("-25"), result.stressed_net_cash
  end

  test "fails loudly when risk and forecast populations diverge" do
    IncomeEvent.create!(
      family: @family,
      canonical_key: "mismatch-income",
      state: "forecast",
      income_type: "interest",
      gross_amount: 100,
      currency: "GBP",
      expected_on: @date + 10.days,
      confidence: "confirmed"
    )

    horizons = WealthOs::DailyClose::ForecastBuilder::HORIZONS.index_with do |days|
      {
        "through_date" => (@date + days.days).iso8601,
        "income" => BigDecimal("0"),
        "liability_payments" => BigDecimal("0"),
        "net_cash" => BigDecimal("0")
      }
    end
    forecast = WealthOs::DailyClose::ForecastBuilder::Result.new(horizons, 0)

    assert_raises(WealthOs::DailyClose::IncomeRiskBuilder::BaselineMismatch) do
      WealthOs::DailyClose::IncomeRiskBuilder.new(
        family: @family,
        close_date: @date,
        reporting_currency: "GBP",
        fx_resolver: @resolver,
        forecast: forecast
      ).call
    end
  end

  test "unknown confidence retains zero stressed income" do
    IncomeEvent.create!(
      family: @family,
      canonical_key: "unknown-income",
      state: "declared",
      income_type: "distribution",
      gross_amount: 80,
      currency: "GBP",
      declared_on: @date,
      payable_on: @date + 10.days,
      confidence: "unknown"
    )

    result = build(liabilities: 0)

    assert_equal BigDecimal("80"), result.baseline_income
    assert_equal BigDecimal("0"), result.stressed_income
    assert_equal BigDecimal("80"), result.income_at_risk
    assert_equal BigDecimal("0"), result.sustainability_ratio
  end

  private

    def build(liabilities:)
      horizons = WealthOs::DailyClose::ForecastBuilder::HORIZONS.index_with do |days|
        {
          "through_date" => (@date + days.days).iso8601,
          "income" => BigDecimal("0"),
          "liability_payments" => days == 365 ? BigDecimal(liabilities.to_s) : BigDecimal("0"),
          "net_cash" => BigDecimal("0")
        }
      end
      dated_income = IncomeEvent.where(family_id: @family.id, state: %w[forecast accrued declared]).sum do |event|
        due = event.payable_on || event.expected_on || event.accrual_end_date
        next BigDecimal("0") unless due && due > @date && due <= @date + 365.days

        event.net_amount.to_d
      end
      horizons.fetch(365)["income"] = dated_income
      forecast = WealthOs::DailyClose::ForecastBuilder::Result.new(horizons, 0)

      WealthOs::DailyClose::IncomeRiskBuilder.new(
        family: @family,
        close_date: @date,
        reporting_currency: "GBP",
        fx_resolver: @resolver,
        forecast: forecast
      ).call
    end
end

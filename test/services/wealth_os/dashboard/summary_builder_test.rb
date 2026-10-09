# frozen_string_literal: true

require "test_helper"

class WealthOs::Dashboard::SummaryBuilderTest < ActiveSupport::TestCase
  setup do
    @family = families(:dylan_family)
    @date = Date.new(2026, 10, 9)
    @cutoff = WealthOs::DailyClose::Configuration.cutoff_at(@date)
  end

  test "builds authoritative dashboard metrics with explicit liquidity policies" do
    snapshot = capture_snapshot(
      valuation_rows: [
        account_row("Depository", "asset", 1_000),
        account_row("Investment", "asset", 2_000),
        account_row("Property", "asset", 5_000),
        account_row("Loan", "liability", 1_500)
      ]
    )

    result = WealthOs::Dashboard::SummaryBuilder.call(snapshot: snapshot)

    assert_equal BigDecimal("8000"), result.gross_assets
    assert_equal BigDecimal("1500"), result.total_liabilities
    assert_equal BigDecimal("6500"), result.net_worth
    assert_equal BigDecimal("1000"), result.liquid_assets
    assert_equal BigDecimal("-500"), result.liquid_net_worth
    assert_equal BigDecimal("3000"), result.investable_assets
    assert_equal BigDecimal("1500"), result.investable_net_worth
    assert_equal %w[Depository], result.classification_policy.fetch("liquid_net_worth").fetch("asset_types")
    assert_equal %w[Depository Investment Crypto],
      result.classification_policy.fetch("investable_net_worth").fetch("asset_types")
  end

  test "does not backfill missing historic account types from current account data" do
    snapshot = capture_snapshot(
      valuation_rows: [
        {
          "account_id" => accounts(:depository).id,
          "name" => "Legacy asset",
          "classification" => "asset",
          "currency" => "GBP",
          "reporting_currency" => "GBP",
          "reporting_value" => "1000"
        }
      ]
    )

    result = WealthOs::Dashboard::SummaryBuilder.call(snapshot: snapshot)

    assert_nil result.liquid_net_worth
    assert_nil result.investable_net_worth
    assert_equal 1, result.data_completeness.fetch("unclassified_snapshot_accounts")
  end

  test "exposes deterministic income resilience metrics from the immutable close" do
    snapshot = capture_snapshot(valuation_rows: [])
    result = WealthOs::Dashboard::SummaryBuilder.call(snapshot: snapshot)

    assert_equal true, result.income_resilience.fetch("available")
    assert_equal "deterministic_income_stress", result.income_resilience.fetch("model")
    assert_equal false, result.income_resilience.fetch("statistical_var")
    assert_equal BigDecimal("1200"), result.income_resilience.fetch("baseline_income")
    assert_equal BigDecimal("900"), result.income_resilience.fetch("stressed_income")
    assert_equal BigDecimal("300"), result.income_resilience.fetch("income_at_risk")
    assert_equal BigDecimal("0.75"), result.income_resilience.fetch("sustainability_ratio")
    assert_equal BigDecimal("600"), result.income_resilience.fetch("stressed_net_cash")
  end

  test "derives annual monthly and daily equivalents from the 365 day contractual forecast" do
    snapshot = capture_snapshot(valuation_rows: [])
    result = WealthOs::Dashboard::SummaryBuilder.call(snapshot: snapshot)

    assert_equal BigDecimal("1200"), result.income_equivalents.fetch("annual")
    assert_equal BigDecimal("100"), result.income_equivalents.fetch("monthly")
    assert_equal BigDecimal("1200") / 365, result.income_equivalents.fetch("daily")
    assert_equal "365_day_contractual_income_forecast", result.income_equivalents.fetch("basis")
  end

  private

    def account_row(type, classification, value)
      {
        "account_id" => SecureRandom.uuid,
        "name" => type,
        "classification" => classification,
        "accountable_type" => type,
        "currency" => "GBP",
        "native_value" => value.to_s,
        "reporting_currency" => "GBP",
        "reporting_value" => value.to_s,
        "fx" => {
          "from_currency" => "GBP", "to_currency" => "GBP", "rate" => "1",
          "rate_date" => @date.iso8601, "requested_date" => @date.iso8601,
          "age_days" => 0, "source" => "identity"
        }
      }
    end

    def capture_snapshot(valuation_rows:)
      DailyCloseSnapshot.capture!(
        family: @family,
        close_date: @date,
        cutoff_at: @cutoff,
        closed_at: @cutoff + 1.minute,
        timezone: "Europe/London",
        reporting_currency: "GBP",
        quality_status: "pass",
        confidence: 1,
        gross_assets: 8_000,
        total_liabilities: 1_500,
        net_worth: 6_500,
        payload: {
          "valuation" => { "accounts" => valuation_rows },
          "income_and_liabilities" => {
            "income_by_state" => {
              "forecast" => "500", "accrued" => "100", "declared" => "200", "received" => "300"
            }
          },
          "forecast" => {
            "horizons" => {
              "7" => forecast_row(7, 100, 20),
              "30" => forecast_row(30, 300, 50),
              "90" => forecast_row(90, 600, 100),
              "365" => forecast_row(365, 1_200, 300)
            },
            "undated_income_count" => 1
          },
          "income_risk" => {
            "model" => "deterministic_income_stress",
            "statistical_var" => false,
            "baseline_income" => "1200",
            "stressed_income" => "900",
            "income_at_risk" => "300",
            "sustainability_ratio" => "0.75",
            "scheduled_liabilities" => "300",
            "stressed_net_cash" => "600",
            "undated_income_count" => 1,
            "undated_income_amount" => "50",
            "top_source_share" => "0.4",
            "concentration_hhi" => "0.3",
            "policy" => { "description" => "deterministic stress retention; not probabilistic VaR" }
          },
          "quality" => {
            "details" => {
              "open_source_conflicts" => 0, "failed_reconciliations" => 0,
              "reconciliation_warnings" => 0, "failed_or_stale_syncs" => 0,
              "stale_fx_rates" => 0
            }
          },
          "action_now" => [ { "action" => "NO ACTION" } ],
          "performance" => { "available" => false }
        }
      )
    end

    def forecast_row(days, income, liabilities)
      {
        "through_date" => (@date + days.days).iso8601,
        "income" => income.to_s,
        "liability_payments" => liabilities.to_s,
        "net_cash" => (income - liabilities).to_s
      }
    end
end

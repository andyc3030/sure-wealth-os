# frozen_string_literal: true

require "test_helper"

class WealthOs::Dashboard::ProvenanceBuilderTest < ActiveSupport::TestCase
  test "traces an income-state metric to the close-time manifest" do
    family = families(:dylan_family)
    date = Date.new(2026, 10, 10)
    cutoff = WealthOs::DailyClose::Configuration.cutoff_at(date)

    payload = {
      "valuation" => {
        "accounts" => [
          {
            "account_id" => SecureRandom.uuid, "name" => "Cash", "classification" => "asset",
            "accountable_type" => "Depository", "reporting_value" => "1000"
          }
        ]
      },
      "income_and_liabilities" => {
        "income_by_state" => {
          "forecast" => "125", "accrued" => "0", "declared" => "0", "received" => "0"
        }
      },
      "forecast" => {
        "horizons" => {
          "7" => row(date, 7), "30" => row(date, 30),
          "90" => row(date, 90), "365" => row(date, 365)
        },
        "undated_income_count" => 0
      },
      "quality" => { "details" => {} },
      "provenance" => {
        "income_events" => [
          {
            "id" => SecureRandom.uuid, "canonical_key" => "forecast-1", "state" => "forecast",
            "currency" => "GBP", "net_amount" => "125",
            "expected_on" => (date + 5.days).iso8601,
            "raw_source_record_id" => SecureRandom.uuid
          }
        ]
      }
    }

    snapshot = DailyCloseSnapshot.capture!(
      family: family, close_date: date, cutoff_at: cutoff, closed_at: cutoff + 1.minute,
      timezone: "Europe/London", reporting_currency: "GBP",
      quality_status: "pass", confidence: 1,
      gross_assets: 1_000, total_liabilities: 0, net_worth: 1_000, payload: payload
    )

    result = WealthOs::Dashboard::ProvenanceBuilder.call(snapshot: snapshot, metric: "income_forecast")

    assert_equal "125.0", result.fetch("value")
    assert_equal "captured_at_close", result.fetch("lineage_status")
    assert_equal "forecast-1", result.fetch("components").first.fetch("canonical_key")
  end

  test "traces deterministic Income-at-Risk to captured stress policy and events" do
    family = families(:dylan_family)
    date = Date.new(2026, 10, 17)
    cutoff = WealthOs::DailyClose::Configuration.cutoff_at(date)

    snapshot = DailyCloseSnapshot.capture!(
      family: family, close_date: date, cutoff_at: cutoff, closed_at: cutoff + 1.minute,
      timezone: "Europe/London", reporting_currency: "GBP",
      quality_status: "pass", confidence: 1,
      gross_assets: 0, total_liabilities: 0, net_worth: 0,
      payload: {
        "valuation" => { "accounts" => [] },
        "income_and_liabilities" => {
          "income_by_state" => {
            "forecast" => "100", "accrued" => "0", "declared" => "0", "received" => "0"
          }
        },
        "forecast" => {
          "horizons" => {
            "7" => row(date, 7), "30" => row(date, 30),
            "90" => row(date, 90), "365" => row(date, 365)
          },
          "undated_income_count" => 0
        },
        "income_risk" => {
          "model" => "deterministic_income_stress",
          "statistical_var" => false,
          "baseline_income" => "100",
          "stressed_income" => "52.5",
          "income_at_risk" => "47.5",
          "sustainability_ratio" => "0.525",
          "scheduled_liabilities" => "10",
          "stressed_net_cash" => "42.5",
          "undated_income_count" => 0,
          "undated_income_amount" => "0",
          "top_source_share" => "1",
          "concentration_hhi" => "1",
          "events" => [
            {
              "income_event_id" => "event-1",
              "state" => "forecast",
              "confidence" => "estimated",
              "reporting_amount" => "100",
              "effective_retention" => "0.525",
              "stressed_amount" => "52.5",
              "at_risk_amount" => "47.5"
            }
          ],
          "source_breakdown" => [
            { "source_key" => "income_type:interest", "amount" => "100", "share" => "1" }
          ],
          "policy" => {
            "description" => "deterministic stress retention; not probabilistic VaR"
          }
        },
        "quality" => { "details" => {} }, "provenance" => {}
      }
    )

    result = WealthOs::Dashboard::ProvenanceBuilder.call(
      snapshot: snapshot,
      metric: "income_at_risk_365"
    )

    assert_equal "47.5", result.fetch("value")
    assert_equal false, result.dig("components", "statistical_var")
    assert_equal "event-1", result.dig("components", "events", 0, "income_event_id")
    assert_includes result.fetch("calculation"), "baseline income minus"
  end

  test "marks pre-Phase-8 risk provenance as unavailable" do
    family = families(:dylan_family)
    date = Date.new(2026, 10, 18)
    cutoff = WealthOs::DailyClose::Configuration.cutoff_at(date)

    snapshot = DailyCloseSnapshot.capture!(
      family: family, close_date: date, cutoff_at: cutoff, closed_at: cutoff + 1.minute,
      timezone: "Europe/London", reporting_currency: "GBP",
      quality_status: "pass", confidence: 1,
      gross_assets: 0, total_liabilities: 0, net_worth: 0,
      payload: {
        "valuation" => { "accounts" => [] },
        "income_and_liabilities" => {
          "income_by_state" => {
            "forecast" => "0", "accrued" => "0", "declared" => "0", "received" => "0"
          }
        },
        "forecast" => {
          "horizons" => {
            "7" => row(date, 7), "30" => row(date, 30),
            "90" => row(date, 90), "365" => row(date, 365)
          },
          "undated_income_count" => 0
        },
        "quality" => { "details" => {} },
        "provenance" => { "captured_at_cutoff" => cutoff.iso8601 }
      }
    )

    result = WealthOs::Dashboard::ProvenanceBuilder.call(
      snapshot: snapshot,
      metric: "income_at_risk_365"
    )

    assert_nil result.fetch("value")
    assert_equal "legacy_snapshot_without_phase8_income_risk", result.fetch("lineage_status")
  end

  test "returns the exact requested forecast component" do
    family = families(:dylan_family)
    date = Date.new(2026, 10, 16)
    cutoff = WealthOs::DailyClose::Configuration.cutoff_at(date)

    snapshot = DailyCloseSnapshot.capture!(
      family: family,
      close_date: date,
      cutoff_at: cutoff,
      closed_at: cutoff + 1.minute,
      timezone: "Europe/London",
      reporting_currency: "GBP",
      quality_status: "pass",
      confidence: 1,
      gross_assets: 0,
      total_liabilities: 0,
      net_worth: 0,
      payload: {
        "valuation" => { "accounts" => [] },
        "income_and_liabilities" => {
          "income_by_state" => {
            "forecast" => "0", "accrued" => "0", "declared" => "0", "received" => "0"
          }
        },
        "forecast" => {
          "horizons" => {
            "7" => {
              "through_date" => (date + 7.days).iso8601,
              "income" => "125",
              "liability_payments" => "25",
              "net_cash" => "100"
            },
            "30" => row(date, 30), "90" => row(date, 90), "365" => row(date, 365)
          },
          "undated_income_count" => 0
        },
        "quality" => { "details" => {} },
        "provenance" => {}
      }
    )

    income = WealthOs::Dashboard::ProvenanceBuilder.call(snapshot: snapshot, metric: "forecast_7_income")
    liabilities = WealthOs::Dashboard::ProvenanceBuilder.call(snapshot: snapshot, metric: "forecast_7_liabilities")
    net = WealthOs::Dashboard::ProvenanceBuilder.call(snapshot: snapshot, metric: "forecast_7_net")

    assert_equal "125.0", income.fetch("value")
    assert_equal "25.0", liabilities.fetch("value")
    assert_equal "100.0", net.fetch("value")
  end

  private

    def row(date, days)
      {
        "through_date" => (date + days.days).iso8601,
        "income" => "0", "liability_payments" => "0", "net_cash" => "0"
      }
    end
end

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

  private

    def row(date, days)
      {
        "through_date" => (date + days.days).iso8601,
        "income" => "0", "liability_payments" => "0", "net_cash" => "0"
      }
    end
end

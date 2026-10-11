# frozen_string_literal: true

require "test_helper"

class WealthOsDashboardIntegrationTest < ActionDispatch::IntegrationTest
  setup do
    sign_in @user = users(:family_admin)
    @family = @user.family
  end

  test "existing dashboard renders the authoritative close widget and provenance links" do
    date = Date.new(2026, 10, 15)
    cutoff = WealthOs::DailyClose::Configuration.cutoff_at(date)

    DailyCloseSnapshot.capture!(
      family: @family, close_date: date, cutoff_at: cutoff, closed_at: cutoff + 1.minute,
      timezone: "Europe/London", reporting_currency: "GBP",
      quality_status: "pass", confidence: 1,
      gross_assets: 100, total_liabilities: 25, net_worth: 75,
      payload: {
        "valuation" => { "accounts" => [] },
        "income_and_liabilities" => {
          "income_by_state" => {
            "forecast" => "0", "accrued" => "0", "declared" => "0", "received" => "0"
          }
        },
        "forecast" => {
          "horizons" => [ 7, 30, 90, 365 ].to_h { |days|
            [ days.to_s, {
              "through_date" => (date + days.days).iso8601,
              "income" => "0", "liability_payments" => "0", "net_cash" => "0"
            } ]
          },
          "undated_income_count" => 0
        },
        "income_risk" => {
          "model" => "deterministic_income_stress",
          "statistical_var" => false,
          "baseline_income" => "100",
          "stressed_income" => "75",
          "income_at_risk" => "25",
          "sustainability_ratio" => "0.75",
          "scheduled_liabilities" => "25",
          "stressed_net_cash" => "50",
          "undated_income_count" => 0,
          "undated_income_amount" => "0",
          "top_source_share" => "1",
          "concentration_hhi" => "1",
          "policy" => {}
        },
        "quality" => { "details" => {} },
        "action_now" => [ { "action" => "NO ACTION" } ]
      }
    )

    get root_path

    assert_response :ok
    assert_select "section[data-section-key='wealth_os_summary']"
    assert_select "a[href*='/wealth_os/snapshots/'][href$='/provenance/net_worth']"
    assert_select "#wealth-os-summary", text: /Liquid net worth/
    assert_select "#wealth-os-summary", text: /Income resilience \(365 days\)/
    assert_select "a[href*='/wealth_os/snapshots/'][href$='/provenance/income_at_risk_365']"
  end

  test "family member does not receive the family-wide authoritative close widget" do
    date = Date.new(2026, 10, 16)
    cutoff = WealthOs::DailyClose::Configuration.cutoff_at(date)
    DailyCloseSnapshot.capture!(
      family: @family,
      close_date: date,
      cutoff_at: cutoff,
      closed_at: cutoff + 1.minute,
      timezone: "Europe/London",
      reporting_currency: "GBP",
      quality_status: "pass",
      confidence: 1,
      gross_assets: 100,
      total_liabilities: 25,
      net_worth: 75,
      payload: {
        "valuation" => { "accounts" => [] },
        "income_and_liabilities" => {
          "income_by_state" => {
            "forecast" => "0", "accrued" => "0", "declared" => "0", "received" => "0"
          }
        },
        "forecast" => {
          "horizons" => [ 7, 30, 90, 365 ].to_h { |days|
            [ days.to_s, {
              "through_date" => (date + days.days).iso8601,
              "income" => "0", "liability_payments" => "0", "net_cash" => "0"
            } ]
          },
          "undated_income_count" => 0
        },
        "quality" => { "details" => {} }
      }
    )
    sign_in users(:family_member)

    get root_path

    assert_response :ok
    assert_select "section[data-section-key='wealth_os_summary']", count: 0
  end
end

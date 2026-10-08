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
        "quality" => { "details" => {} },
        "action_now" => [ { "action" => "NO ACTION" } ]
      }
    )

    get root_path

    assert_response :ok
    assert_select "section[data-section-key='wealth_os_summary']"
    assert_select "a[href*='/wealth_os/snapshots/'][href$='/provenance/net_worth']"
    assert_select "#wealth-os-summary", text: /Liquid net worth/
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

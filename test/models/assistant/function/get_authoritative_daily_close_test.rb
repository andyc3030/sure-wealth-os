# frozen_string_literal: true

require "test_helper"

class Assistant::Function::GetAuthoritativeDailyCloseTest < ActiveSupport::TestCase
  test "returns the latest immutable close for the user's family" do
    user = users(:family_admin)
    family = user.family
    date = Date.new(2026, 10, 11)
    cutoff = WealthOs::DailyClose::Configuration.cutoff_at(date)

    DailyCloseSnapshot.capture!(
      family: family, close_date: date, cutoff_at: cutoff, closed_at: cutoff + 1.minute,
      timezone: "Europe/London", reporting_currency: "GBP",
      quality_status: "pass", confidence: 1,
      gross_assets: 1_500, total_liabilities: 500, net_worth: 1_000,
      payload: minimal_payload(date)
    )

    result = Assistant::Function::GetAuthoritativeDailyClose.new(user).call

    assert_equal true, result.fetch("authoritative")
    assert_equal true, result.fetch("immutable")
    assert_equal "1000.0", result.fetch("net_worth")
    assert_equal date.iso8601, result.fetch("close_date")
  end

  test "does not expose family-wide close to a non-admin family member" do
    user = users(:family_member)

    result = Assistant::Function::GetAuthoritativeDailyClose.new(user).call

    assert_equal "authoritative_close_not_available", result.fetch("error")
  end

  private

    def minimal_payload(date)
      horizons = [ 7, 30, 90, 365 ].to_h do |days|
        [ days.to_s, {
          "through_date" => (date + days.days).iso8601,
          "income" => "0", "liability_payments" => "0", "net_cash" => "0"
        } ]
      end

      {
        "valuation" => { "accounts" => [] },
        "income_and_liabilities" => {
          "income_by_state" => {
            "forecast" => "0", "accrued" => "0", "declared" => "0", "received" => "0"
          }
        },
        "forecast" => { "horizons" => horizons, "undated_income_count" => 0 },
        "quality" => { "details" => {} }, "action_now" => []
      }
    end
end

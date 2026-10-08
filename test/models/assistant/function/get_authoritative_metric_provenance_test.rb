# frozen_string_literal: true

require "test_helper"

class Assistant::Function::GetAuthoritativeMetricProvenanceTest < ActiveSupport::TestCase
  test "cannot read a close belonging to another family by date" do
    user = users(:family_admin)
    other_family = Family.where.not(id: user.family_id).first
    skip "fixture requires a second family" unless other_family

    date = Date.new(2026, 10, 12)
    cutoff = WealthOs::DailyClose::Configuration.cutoff_at(date)

    DailyCloseSnapshot.capture!(
      family: other_family, close_date: date, cutoff_at: cutoff, closed_at: cutoff + 1.minute,
      timezone: "Europe/London", reporting_currency: "GBP",
      quality_status: "pass", confidence: 1,
      gross_assets: 100, total_liabilities: 0, net_worth: 100,
      payload: minimal_payload(date)
    )

    result = Assistant::Function::GetAuthoritativeMetricProvenance.new(user).call(
      "metric" => "net_worth", "close_date" => date.iso8601
    )

    assert_equal "authoritative_close_not_found", result.fetch("error")
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
        "quality" => { "details" => {} }, "provenance" => {}
      }
    end
end

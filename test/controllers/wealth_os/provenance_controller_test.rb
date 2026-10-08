# frozen_string_literal: true

require "test_helper"

class WealthOs::ProvenanceControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in @user = users(:family_admin)
    @family = @user.family
  end

  test "renders provenance for a snapshot in the current family" do
    snapshot = create_snapshot(@family, Date.new(2026, 10, 13))

    get wealth_os_snapshot_provenance_path(snapshot_id: snapshot.id, metric: "net_worth")

    assert_response :ok
    assert_select "h1", text: "Authoritative metric provenance"
    assert_select "pre", minimum: 1
  end

  test "returns not found to a non-admin member of the same family" do
    snapshot = create_snapshot(@family, Date.new(2026, 10, 14))
    sign_in users(:family_member)

    get wealth_os_snapshot_provenance_path(snapshot_id: snapshot.id, metric: "net_worth")

    assert_response :not_found
  end

  test "returns not found for another family's snapshot" do
    other_family = Family.where.not(id: @family.id).first
    skip "fixture requires a second family" unless other_family
    snapshot = create_snapshot(other_family, Date.new(2026, 10, 14))

    get wealth_os_snapshot_provenance_path(snapshot_id: snapshot.id, metric: "net_worth")

    assert_response :not_found
  end

  private

    def create_snapshot(family, date)
      cutoff = WealthOs::DailyClose::Configuration.cutoff_at(date)
      DailyCloseSnapshot.capture!(
        family: family, close_date: date, cutoff_at: cutoff, closed_at: cutoff + 1.minute,
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
          "quality" => { "details" => {} }, "provenance" => {}
        }
      )
    end
end

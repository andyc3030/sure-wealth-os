# frozen_string_literal: true

require "test_helper"

class WealthOs::DailyClose::ActionNowBuilderTest < ActiveSupport::TestCase
  Quality = Data.define(:details)
  Forecast = Data.define(:horizons)

  test "returns no action only when there are no deterministic exceptions" do
    quality = Quality.new({
      "open_source_conflicts" => 0,
      "material_open_source_conflicts" => 0,
      "failed_reconciliations" => 0,
      "material_failed_reconciliations" => 0,
      "reconciliation_warnings" => 0,
      "failed_or_stale_syncs" => 0,
      "stale_fx_rates" => 0
    })
    forecast = Forecast.new({
      30 => {
        "through_date" => "2026-11-07",
        "income" => BigDecimal("100"),
        "liability_payments" => BigDecimal("50"),
        "net_cash" => BigDecimal("50")
      }
    })

    actions = WealthOs::DailyClose::ActionNowBuilder.call(
      quality: quality,
      forecast: forecast
    )

    assert_predicate actions, :one?
    assert_equal "NO ACTION", actions.first.fetch("action")
  end
end

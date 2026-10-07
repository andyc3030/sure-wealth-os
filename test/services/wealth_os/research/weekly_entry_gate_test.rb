require "test_helper"

class WealthOs::Research::WeeklyEntryGateTest < ActiveSupport::TestCase
  test "passes only when Friday NY bar reclaims 50W, stays above 250W and is near 10W" do
    friday_close = ActiveSupport::TimeZone["America/New_York"].parse("2026-10-09 16:00:00")

    result = WealthOs::Research::WeeklyEntryGate.call(
      open: 95,
      close: 105,
      sma_10w: 104,
      sma_50w: 100,
      sma_250w: 90,
      near_10w_tolerance_pct: 2,
      bar_closed_at: friday_close
    )

    assert_equal "pass", result[:status]
    assert result[:reclaim_50w]
    assert result[:above_250w]
    assert result[:near_10w]
    assert result[:advisory_only]
  end

  test "returns insufficient evidence when near-10W tolerance is not configured" do
    friday_close = ActiveSupport::TimeZone["America/New_York"].parse("2026-10-09 16:00:00")

    result = WealthOs::Research::WeeklyEntryGate.call(
      open: 95,
      close: 105,
      sma_10w: 104,
      sma_50w: 100,
      sma_250w: 90,
      near_10w_tolerance_pct: nil,
      bar_closed_at: friday_close
    )

    assert_equal "insufficient_evidence", result[:status]
    assert_includes result[:reason], "tolerance"
  end

  test "fails when any technical condition fails" do
    friday_close = ActiveSupport::TimeZone["America/New_York"].parse("2026-10-09 16:00:00")

    result = WealthOs::Research::WeeklyEntryGate.call(
      open: 95,
      close: 101,
      sma_10w: 110,
      sma_50w: 100,
      sma_250w: 102,
      near_10w_tolerance_pct: 2,
      bar_closed_at: friday_close
    )

    assert_equal "fail", result[:status]
    assert result[:reclaim_50w]
    assert_not result[:above_250w]
    assert_not result[:near_10w]
  end
end

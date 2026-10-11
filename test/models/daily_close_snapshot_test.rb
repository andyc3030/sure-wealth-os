# frozen_string_literal: true

require "test_helper"

class DailyCloseSnapshotTest < ActiveSupport::TestCase
  setup do
    @family = families(:dylan_family)
    @date = Date.new(2026, 10, 8)
    @cutoff = WealthOs::DailyClose::Configuration.cutoff_at(@date)
    @payload = {
      "close_date" => @date.iso8601,
      "valuation" => { "net_worth" => "750.0" }
    }
  end

  test "capture is idempotent for identical financial content" do
    snapshot = capture(@payload)
    replay = capture(@payload)

    assert_equal snapshot.id, replay.id
    assert_match(/\A[0-9a-f]{64}\z/, snapshot.payload_sha256)
  end

  test "same close date with changed content fails loudly" do
    capture(@payload)

    assert_raises(DailyCloseSnapshot::IdempotencyCollision) do
      capture(@payload.deep_merge("valuation" => { "net_worth" => "751.0" }))
    end
  end

  test "snapshot rows cannot be changed after creation" do
    snapshot = capture(@payload)

    assert_not snapshot.update(close_date: @date - 1.day)
    assert_includes snapshot.errors.full_messages.join(" "), "immutable"
  end

  private

    def capture(payload)
      DailyCloseSnapshot.capture!(
        family: @family,
        close_date: @date,
        cutoff_at: @cutoff,
        closed_at: @cutoff + 1.minute,
        timezone: "Europe/London",
        reporting_currency: "GBP",
        quality_status: "pass",
        confidence: 1,
        gross_assets: 1_000,
        total_liabilities: 250,
        net_worth: 750,
        payload: payload
      )
    end
end

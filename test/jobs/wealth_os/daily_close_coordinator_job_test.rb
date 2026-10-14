# frozen_string_literal: true

require "test_helper"

class WealthOs::DailyCloseCoordinatorJobTest < ActiveJob::TestCase
  test "retries an overdue prior-day close outside the midnight hour" do
    family = families(:dylan_family)
    now = Time.utc(2026, 10, 8, 9, 0)

    Family.stubs(:find_each).yields(family)
    DailyCloseSnapshot.stubs(:exists?).returns(false)
    WealthOs::DailyClose::Orchestrator.expects(:call).with(
      family: family,
      close_date: Date.new(2026, 10, 7),
      now: now
    )

    WealthOs::DailyCloseCoordinatorJob.perform_now(now: now)
  end

  test "pre-close window requests sync and still retries the prior close" do
    family = families(:dylan_family)
    now = Time.utc(2026, 10, 8, 22, 30)

    Family.stubs(:find_each).twice.yields(family)
    Sync.stubs(:any_incomplete_for?).with(family).returns(false)
    family.expects(:sync_later)
    DailyCloseSnapshot.stubs(:exists?).returns(false)
    WealthOs::DailyClose::Orchestrator.expects(:call).with(
      family: family,
      close_date: Date.new(2026, 10, 7),
      now: now
    )

    WealthOs::DailyCloseCoordinatorJob.perform_now(now: now)
  end

  test "logs a certification block and independently finalizes the next family" do
    blocked_family = families(:dylan_family)
    next_family = families(:empty)
    now = Time.utc(2026, 10, 8, 9, 0)
    date = Date.new(2026, 10, 7)
    result = WealthOs::DailyClose::CertificationGate::Result.new([
      { "account_id" => accounts(:connected).id, "provider_key" => "plaid_uk",
        "institution_key" => "ins_63", "source_identity" => { "type" => "PlaidAccount", "id" => plaid_accounts(:one).id },
        "approved" => false, "reason" => "no_production_certification", "certification_id" => nil }
    ])
    error = WealthOs::DailyClose::CertificationGate::Rejected.new(result)
    Family.stubs(:find_each).multiple_yields([ blocked_family ], [ next_family ])
    DailyCloseSnapshot.stubs(:exists?).returns(false)
    attempts = sequence("family close attempts")
    WealthOs::DailyClose::Orchestrator.expects(:call).with(
      family: blocked_family, close_date: date, now: now
    ).in_sequence(attempts).raises(error)
    WealthOs::DailyClose::Orchestrator.expects(:call).with(
      family: next_family, close_date: date, now: now
    ).in_sequence(attempts)

    assert_difference "DebugLogEntry.count", 1 do
      WealthOs::DailyCloseCoordinatorJob.perform_now(now: now)
    end

    log = DebugLogEntry.find_by!(family: blocked_family, category: "daily_close", source: "wealth_os_daily_close")
    assert_equal "error", log.level
    assert_equal date.iso8601, log.metadata.fetch("close_date")
    assert_equal result.as_json, log.metadata.fetch("certification")
  end
end

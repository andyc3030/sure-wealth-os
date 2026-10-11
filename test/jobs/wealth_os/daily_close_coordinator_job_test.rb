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
end

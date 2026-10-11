# frozen_string_literal: true

require "test_helper"

class CtraderItem::SyncerTest < ActiveSupport::TestCase
  setup do
    @family = families(:dylan_family)
  end

  test "demo sync remains available for integration testing" do
    item = CtraderItem.create!(family: @family, name: "Demo cTrader", environment: "demo")
    sync = stub(window_start_date: Date.current - 1.day, window_end_date: Date.current)

    item.expects(:import_read_only_snapshot!).once

    CtraderItem::Syncer.new(item).perform_sync(sync)
  end

  test "live automated sync fails closed without production certification" do
    item = CtraderItem.create!(family: @family, name: "Live cTrader", environment: "live")
    sync = stub(window_start_date: nil, window_end_date: nil)

    item.expects(:import_read_only_snapshot!).never

    error = assert_raises(Provider::Ctrader::PermissionError) do
      CtraderItem::Syncer.new(item).perform_sync(sync)
    end

    assert_includes error.message, "requires current production certification"
  end

  test "live automated sync proceeds only after production certification gate passes" do
    item = CtraderItem.create!(family: @family, name: "Live cTrader", environment: "live")
    sync = stub(window_start_date: Date.current - 1.day, window_end_date: Date.current)

    item.stubs(:production_sync_approved?).returns(true)
    item.expects(:import_read_only_snapshot!).once

    CtraderItem::Syncer.new(item).perform_sync(sync)
  end
end

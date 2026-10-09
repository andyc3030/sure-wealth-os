# frozen_string_literal: true

class CtraderItem::SyncCompleteEvent
  def initialize(ctrader_item)
    @ctrader_item = ctrader_item
  end

  def broadcast
    ctrader_item.family.broadcast_sync_complete
  end

  private

    attr_reader :ctrader_item
end

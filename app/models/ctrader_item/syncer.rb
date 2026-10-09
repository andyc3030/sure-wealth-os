# frozen_string_literal: true

class CtraderItem::Syncer
  DEFAULT_HISTORY_DAYS = 90

  def initialize(ctrader_item)
    @ctrader_item = ctrader_item
  end

  def perform_sync(sync)
    from_date = sync.window_start_date || DEFAULT_HISTORY_DAYS.days.ago.to_date
    to_date = sync.window_end_date || Date.current

    ctrader_item.import_read_only_snapshot!(
      from_timestamp: from_date.beginning_of_day,
      to_timestamp: to_date.end_of_day,
      observed_at: Time.current
    )
  end

  def perform_post_sync
  end

  private

    attr_reader :ctrader_item
end

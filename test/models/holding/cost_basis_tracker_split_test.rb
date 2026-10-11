require "test_helper"

class Holding::CostBasisTrackerSplitTest < ActiveSupport::TestCase
  test "split changes units but preserves total cost" do
    tracker = Holding::CostBasisTracker.new
    tracker.apply(100, 10)

    tracker.apply_split(2)

    assert_equal BigDecimal("50"), tracker.average_cost

    tracker.apply(50, -20)
    assert_nil tracker.average_cost
  end
end

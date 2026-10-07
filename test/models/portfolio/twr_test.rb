require "test_helper"

class Portfolio::TwrTest < ActiveSupport::TestCase
  test "chains subperiod returns while neutralising end-of-period external flows" do
    segments = [
      { date: Date.new(2026, 1, 31), begin_value: 100, end_value: 110, external_flow: 0 },
      { date: Date.new(2026, 2, 28), begin_value: 110, end_value: 171, external_flow: 50 }
    ]

    # 10% then 10% = 21% compounded. The 50 contribution is not return.
    assert_in_delta 0.21, Portfolio::Twr.new(segments).rate.to_f, 1e-12
  end

  test "handles a withdrawal as a negative external flow" do
    segments = [
      { date: Date.current, begin_value: 171, end_value: 168.1, external_flow: -20 }
    ]

    assert_in_delta 0.10, Portfolio::Twr.new(segments).rate.to_f, 1e-12
  end

  test "refuses a zero beginning value" do
    twr = Portfolio::Twr.new([
      { date: Date.current, begin_value: 0, end_value: 100, external_flow: 100 }
    ])

    assert_raises(Portfolio::Twr::InvalidSegment) { twr.rate }
  end
  test "rejects duplicate segment dates because ordering would be ambiguous" do
    assert_raises(Portfolio::Twr::InvalidSegment) do
      Portfolio::Twr.new([
        { date: Date.current, begin_value: 100, end_value: 110, external_flow: 0 },
        { date: Date.current, begin_value: 110, end_value: 120, external_flow: 0 }
      ])
    end
  end

  test "rejects nil segment values instead of coercing them to zero" do
    twr = Portfolio::Twr.new([
      { date: Date.current, begin_value: 100, end_value: 110, external_flow: nil }
    ])

    error = assert_raises(Portfolio::Twr::InvalidSegment) { twr.rate }
    assert_equal "external_flow is required", error.message
  end

end

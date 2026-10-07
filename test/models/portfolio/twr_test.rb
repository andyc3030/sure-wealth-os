require "test_helper"

class Portfolio::TwrTest < ActiveSupport::TestCase
  test "single period return excludes a contribution at period end" do
    rate = Portfolio::Twr.rate([
      {
        start_date: Date.new(2026, 1, 1),
        end_date: Date.new(2026, 1, 31),
        opening_value: 100,
        closing_value: 120,
        external_flow_at_end: 10
      }
    ])

    assert_equal BigDecimal("0.1"), rate
  end

  test "geometrically links subperiod returns around external cash flows" do
    twr = Portfolio::Twr.new([
      {
        start_date: Date.new(2026, 1, 1),
        end_date: Date.new(2026, 1, 31),
        opening_value: 100,
        closing_value: 110,
        external_flow_at_end: 0
      },
      {
        start_date: Date.new(2026, 1, 31),
        end_date: Date.new(2026, 2, 28),
        opening_value: 110,
        closing_value: 126,
        external_flow_at_end: 5
      }
    ])

    assert_equal [ BigDecimal("0.1"), BigDecimal("0.1") ], twr.subperiod_rates
    assert_equal BigDecimal("0.21"), twr.rate
  end

  test "withdrawal at period end is removed from performance" do
    rate = Portfolio::Twr.rate([
      {
        start_date: Date.new(2026, 1, 1),
        end_date: Date.new(2026, 1, 31),
        opening_value: 100,
        closing_value: 100,
        external_flow_at_end: -10
      }
    ])

    assert_equal BigDecimal("0.1"), rate
  end

  test "zero opening value and overlapping periods fail loudly" do
    assert_raises(Portfolio::Twr::ZeroOpeningValueError) do
      Portfolio::Twr.rate([
        { start_date: Date.new(2026, 1, 1), end_date: Date.new(2026, 1, 2), opening_value: 0, closing_value: 1 }
      ])
    end

    assert_raises(Portfolio::Twr::InvalidPeriodError) do
      Portfolio::Twr.rate([
        { start_date: Date.new(2026, 1, 1), end_date: Date.new(2026, 1, 10), opening_value: 100, closing_value: 101 },
        { start_date: Date.new(2026, 1, 9), end_date: Date.new(2026, 1, 20), opening_value: 101, closing_value: 102 }
      ])
    end
  end
end

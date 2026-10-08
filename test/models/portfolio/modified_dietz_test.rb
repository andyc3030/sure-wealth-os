require "test_helper"

class Portfolio::ModifiedDietzTest < ActiveSupport::TestCase
  test "weights an intra-period contribution by time invested" do
    rate = Portfolio::ModifiedDietz.rate(
      opening_value: 100,
      closing_value: 165,
      start_date: Date.new(2026, 1, 1),
      end_date: Date.new(2026, 1, 11),
      flows: [
        { date: Date.new(2026, 1, 6), amount: 50 }
      ]
    )

    # Gain = 165 - 100 - 50 = 15; weighted capital = 100 + 50*0.5 = 125.
    assert_in_delta 0.12, rate.to_f, 1e-12
  end

  test "rejects flows outside the measurement period" do
    assert_raises(Portfolio::ModifiedDietz::InvalidPeriodError) do
      Portfolio::ModifiedDietz.new(
        opening_value: 100,
        closing_value: 110,
        start_date: Date.new(2026, 1, 1),
        end_date: Date.new(2026, 1, 31),
        flows: [ { date: Date.new(2025, 12, 31), amount: 10 } ]
      )
    end
  end
end

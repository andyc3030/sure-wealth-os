require "test_helper"

class WealthOs::Performance::PortfolioReturnsTest < ActiveSupport::TestCase
  test "reports TWR and existing XIRR side by side" do
    result = WealthOs::Performance::PortfolioReturns.call(
      twr_subperiods: [
        { opening_value: 1000, closing_value: 1100, external_flow: 0, flow_timing: :none }
      ],
      xirr_flows: [
        [ Date.new(2025, 1, 1), -1000 ],
        [ Date.new(2026, 1, 1), 1100 ]
      ]
    )

    assert_in_delta 0.10, result.time_weighted_return.to_f, 1e-12
    assert_in_delta 0.10, result.money_weighted_return.to_f, 1e-6
    assert_equal false, result.money_weighted_ambiguous
  end
end

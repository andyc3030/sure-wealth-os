require "test_helper"

class Portfolio::TwrTest < ActiveSupport::TestCase
  test "chain-links subperiod returns" do
    rate = Portfolio::Twr.rate([
      { opening_value: 100, closing_value: 110, external_flow: 0, flow_timing: :none },
      { opening_value: 110, closing_value: 99, external_flow: 0, flow_timing: :none }
    ])

    assert_in_delta(-0.01, rate.to_f, 1e-12)
  end

  test "removes an end-of-period contribution from investment return" do
    rate = Portfolio::Twr.rate([
      { opening_value: 100, closing_value: 120, external_flow: 10, flow_timing: :end }
    ])

    assert_in_delta 0.10, rate.to_f, 1e-12
  end

  test "includes a beginning-of-period contribution in invested capital" do
    rate = Portfolio::Twr.rate([
      { opening_value: 100, closing_value: 165, external_flow: 50, flow_timing: :begin }
    ])

    assert_in_delta 0.10, rate.to_f, 1e-12
  end

  test "fails rather than fabricating a return with nonpositive denominator" do
    assert_raises(Portfolio::Twr::InvalidSubperiodError) do
      Portfolio::Twr.rate([
        { opening_value: 0, closing_value: 10, external_flow: 0, flow_timing: :none }
      ])
    end
  end
end

# frozen_string_literal: true

require "test_helper"

class Provider::Ctrader::JsonWebSocketTransportTest < ActiveSupport::TestCase
  test "uses the official JSON WebSocket endpoint for each isolated environment" do
    demo = Provider::Ctrader::JsonWebSocketTransport.new(environment: "demo")
    live = Provider::Ctrader::JsonWebSocketTransport.new(environment: "live")

    assert_equal "wss://demo.ctraderapi.com:5036", demo.url
    assert_equal "wss://live.ctraderapi.com:5036", live.url
  ensure
    demo&.close
    live&.close
  end

  test "rejects unknown environments before a socket can be opened" do
    assert_raises(ArgumentError) do
      Provider::Ctrader::JsonWebSocketTransport.new(environment: "production")
    end
  end
end

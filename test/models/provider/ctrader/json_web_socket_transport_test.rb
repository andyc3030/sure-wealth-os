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

  test "token invalidation fails pending reads and poisons the transport" do
    transport = Provider::Ctrader::JsonWebSocketTransport.new(environment: "demo")
    queue = Queue.new
    transport.instance_variable_get(:@pending_mutex).synchronize do
      transport.instance_variable_get(:@pending)["pending-1"] = queue
    end

    transport.send(
      :handle_message,
      JSON.generate(
        "payloadType" => Provider::Ctrader::JsonWebSocketTransport::TOKEN_INVALIDATED_PAYLOAD_TYPE,
        "payload" => { "reason" => "Access Token is expired or recalled" }
      )
    )

    error = queue.pop
    assert_instance_of Provider::Ctrader::AuthenticationError, error
    assert_includes error.message, "invalidated"
    assert_instance_of(
      Provider::Ctrader::AuthenticationError,
      transport.instance_variable_get(:@authentication_error)
    )
  ensure
    transport&.close
  end

  test "rejects unknown environments before a socket can be opened" do
    assert_raises(ArgumentError) do
      Provider::Ctrader::JsonWebSocketTransport.new(environment: "production")
    end
  end
end

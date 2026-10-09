# frozen_string_literal: true

require "test_helper"

class Provider::Ctrader::ReadOnlyGatewayTest < ActiveSupport::TestCase
  class FakeTransport
    attr_reader :calls

    def initialize(responses = {})
      @responses = responses
      @calls = []
    end

    def call(payload_type:, payload:, client_msg_id:)
      @calls << {
        payload_type: payload_type,
        payload: payload,
        client_msg_id: client_msg_id
      }
      @responses.fetch(payload_type, { "payload" => {} })
    end
  end

  test "accepts SCOPE_VIEW account-list permission" do
    transport = FakeTransport.new(
      2149 => {
        "payload" => {
          "permissionScope" => "SCOPE_VIEW",
          "ctidTraderAccount" => [ { "ctidTraderAccountId" => 123 } ]
        }
      }
    )
    gateway = Provider::Ctrader::ReadOnlyGateway.new(transport: transport)

    result = gateway.list_accounts!(access_token: "sensitive-token")

    assert_equal "SCOPE_VIEW", result.fetch("permission_scope")
    assert_equal 123, result.fetch("accounts").first.fetch("ctidTraderAccountId")
  end

  test "rejects trade permission from account-list response" do
    transport = FakeTransport.new(
      2149 => { "payload" => { "permissionScope" => "SCOPE_TRADE" } }
    )
    gateway = Provider::Ctrader::ReadOnlyGateway.new(transport: transport)

    error = assert_raises(Provider::Ctrader::PermissionError) do
      gateway.list_accounts!(access_token: "sensitive-token")
    end

    assert_includes error.message, "requires SCOPE_VIEW"
  end

  test "hard blocks known execution request payloads and unknown requests" do
    gateway = Provider::Ctrader::ReadOnlyGateway.new(transport: FakeTransport.new)

    [ 2106, 2108, 2109, 2110, 2111 ].each do |payload_type|
      assert_raises(Provider::Ctrader::ReadOnlyGateway::UnsupportedRequest) do
        gateway.request_payload_type!(payload_type)
      end
    end

    assert_raises(Provider::Ctrader::ReadOnlyGateway::UnsupportedRequest) do
      gateway.request_payload_type!(9999)
    end
  end

  test "read-only market and account requests remain allowlisted" do
    transport = FakeTransport.new
    gateway = Provider::Ctrader::ReadOnlyGateway.new(transport: transport)

    gateway.request_payload_type!(2121, ctidTraderAccountId: 123)
    gateway.request_payload_type!(2124, ctidTraderAccountId: 123)
    gateway.request_payload_type!(2133, ctidTraderAccountId: 123)

    assert_equal [ 2121, 2124, 2133 ], transport.calls.map { |row| row.fetch(:payload_type) }
  end
end

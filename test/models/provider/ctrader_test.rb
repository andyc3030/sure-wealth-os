# frozen_string_literal: true

require "test_helper"
require "uri"

class Provider::CtraderTest < ActiveSupport::TestCase
  test "authorization URL is permanently accounts-only" do
    Rails.configuration.x.ctrader.client_id = "client-123"
    Rails.configuration.x.ctrader.client_secret = "secret-456"

    uri = URI.parse(
      Provider::Ctrader.authorize_url(redirect_uri: "https://example.test/ctrader/callback")
    )
    params = Rack::Utils.parse_query(uri.query)

    assert_equal "accounts", params.fetch("scope")
    assert_equal "client-123", params.fetch("client_id")
    assert_equal "web", params.fetch("product")
    assert_not_equal "trading", params.fetch("scope")
  ensure
    Rails.configuration.x.ctrader.client_id = ENV["CTRADER_OPEN_API_CLIENT_ID"]
    Rails.configuration.x.ctrader.client_secret = ENV["CTRADER_OPEN_API_CLIENT_SECRET"]
  end
end

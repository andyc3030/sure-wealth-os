# frozen_string_literal: true

class Provider::Ctrader::ReadOnlyGateway
  class UnsupportedRequest < Provider::Ctrader::PermissionError; end

  PAYLOAD_TYPES = {
    application_auth: 2100,
    account_auth: 2102,
    asset_list: 2112,
    symbols_list: 2114,
    trader: 2121,
    reconcile: 2124,
    deal_list: 2133,
    cash_flow_history: 2143,
    get_accounts_by_access_token: 2149,
    order_list: 2175,
    position_unrealized_pnl: 2187
  }.freeze

  EXECUTION_PAYLOAD_TYPES = [ 2106, 2108, 2109, 2110, 2111 ].freeze
  VIEW_PERMISSION_VALUES = [ "SCOPE_VIEW", 0, "0" ].freeze
  TRADE_PERMISSION_VALUES = [ "SCOPE_TRADE", 1, "1" ].freeze
  HISTORICAL_REQUESTS = %i[deal_list cash_flow_history order_list].freeze
  HISTORICAL_MIN_INTERVAL = 0.2
  STANDARD_MIN_INTERVAL = 0.02

  def initialize(transport:)
    @transport = transport
    @rate_mutex = Mutex.new
    @last_request_at = {}
  end

  def authenticate_application!(client_id:, client_secret:)
    request!(:application_auth, clientId: client_id, clientSecret: client_secret)
  end

  def list_accounts!(access_token:)
    payload = request!(:get_accounts_by_access_token, accessToken: access_token)
    assert_view_permission!(payload["permissionScope"])

    {
      "permission_scope" => "SCOPE_VIEW",
      "accounts" => Array(payload["ctidTraderAccount"])
    }
  end

  def authenticate_account!(ctid_trader_account_id:, access_token:)
    request!(
      :account_auth,
      ctidTraderAccountId: ctid_trader_account_id,
      accessToken: access_token
    )
  end

  def asset_list(ctid_trader_account_id:)
    request!(:asset_list, ctidTraderAccountId: ctid_trader_account_id)
  end

  def symbols_list(ctid_trader_account_id:)
    request!(:symbols_list, ctidTraderAccountId: ctid_trader_account_id)
  end

  def trader(ctid_trader_account_id:)
    request!(:trader, ctidTraderAccountId: ctid_trader_account_id)
  end

  def reconcile(ctid_trader_account_id:)
    request!(:reconcile, ctidTraderAccountId: ctid_trader_account_id)
  end

  def deals(ctid_trader_account_id:, from_timestamp:, to_timestamp:)
    request!(
      :deal_list,
      ctidTraderAccountId: ctid_trader_account_id,
      fromTimestamp: from_timestamp,
      toTimestamp: to_timestamp
    )
  end

  def cash_flows(ctid_trader_account_id:, from_timestamp:, to_timestamp:)
    request!(
      :cash_flow_history,
      ctidTraderAccountId: ctid_trader_account_id,
      fromTimestamp: from_timestamp,
      toTimestamp: to_timestamp
    )
  end

  def orders(ctid_trader_account_id:, from_timestamp:, to_timestamp:)
    request!(
      :order_list,
      ctidTraderAccountId: ctid_trader_account_id,
      fromTimestamp: from_timestamp,
      toTimestamp: to_timestamp
    )
  end

  def position_unrealized_pnl(ctid_trader_account_id:)
    request!(:position_unrealized_pnl, ctidTraderAccountId: ctid_trader_account_id)
  end

  def request_payload_type!(payload_type, payload = {})
    if EXECUTION_PAYLOAD_TYPES.include?(payload_type.to_i)
      raise UnsupportedRequest, "cTrader trading request payload #{payload_type} is forbidden"
    end

    name = PAYLOAD_TYPES.key(payload_type.to_i)
    raise UnsupportedRequest, "cTrader request payload #{payload_type} is not allowlisted" unless name

    request!(name, payload)
  end

  private

    attr_reader :transport

    def request!(name, payload)
      payload_type = PAYLOAD_TYPES.fetch(name) do
        raise UnsupportedRequest, "cTrader request #{name} is not allowlisted"
      end

      throttle!(name)

      response = transport.call(
        payload_type: payload_type,
        payload: payload.stringify_keys,
        client_msg_id: SecureRandom.uuid
      )
      extract_payload(response)
    end

    def throttle!(name)
      bucket = HISTORICAL_REQUESTS.include?(name) ? :historical : :standard
      minimum = bucket == :historical ? HISTORICAL_MIN_INTERVAL : STANDARD_MIN_INTERVAL

      @rate_mutex.synchronize do
        now = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        previous = @last_request_at[bucket]
        sleep_time = minimum - (now - previous) if previous
        sleep(sleep_time) if sleep_time&.positive?
        @last_request_at[bucket] = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      end
    end

    def extract_payload(response)
      hash = response.to_h.stringify_keys
      payload = hash["payload"].is_a?(Hash) ? hash["payload"].stringify_keys : hash
      if payload["errorCode"].present?
        raise Provider::Ctrader::Error, "cTrader request failed: #{payload["errorCode"]}"
      end

      payload
    end

    def assert_view_permission!(permission_scope)
      return if VIEW_PERMISSION_VALUES.include?(permission_scope)

      if TRADE_PERMISSION_VALUES.include?(permission_scope)
        raise Provider::Ctrader::PermissionError,
              "cTrader token has trading permission; Wealth OS requires SCOPE_VIEW"
      end

      raise Provider::Ctrader::PermissionError,
            "cTrader permission scope is missing or unrecognized"
    end
end

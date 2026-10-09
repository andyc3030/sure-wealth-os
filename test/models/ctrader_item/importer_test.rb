# frozen_string_literal: true

require "test_helper"

class CtraderItem::ImporterTest < ActiveSupport::TestCase
  class FakeGateway
    attr_reader :calls

    def initialize
      @calls = []
    end

    def authenticate_application!(client_id:, client_secret:)
      calls << [ :application_auth, client_id, client_secret ]
      true
    end

    def list_accounts!(access_token:)
      calls << [ :list_accounts, access_token ]
      {
        "permission_scope" => "SCOPE_VIEW",
        "accounts" => [
          {
            "ctidTraderAccountId" => 123_456,
            "isLive" => false,
            "traderLogin" => 42,
            "brokerTitleShort" => "IC Markets Global"
          },
          {
            "ctidTraderAccountId" => 999_999,
            "isLive" => true,
            "traderLogin" => 99,
            "brokerTitleShort" => "IC Markets Global"
          }
        ]
      }
    end

    def authenticate_account!(ctid_trader_account_id:, access_token:)
      calls << [ :account_auth, ctid_trader_account_id, access_token ]
      true
    end

    def trader(ctid_trader_account_id:)
      calls << [ :trader, ctid_trader_account_id ]
      {
        "ctidTraderAccountId" => ctid_trader_account_id,
        "trader" => {
          "ctidTraderAccountId" => ctid_trader_account_id,
          "balance" => 1_000_00,
          "moneyDigits" => 2,
          "depositAssetId" => 1,
          "traderLogin" => 42,
          "brokerName" => "IC Markets Global"
        }
      }
    end

    def asset_list(ctid_trader_account_id:)
      calls << [ :asset_list, ctid_trader_account_id ]
      { "asset" => [ { "assetId" => 1, "name" => "GBP" } ] }
    end

    def symbols_list(ctid_trader_account_id:)
      calls << [ :symbols_list, ctid_trader_account_id ]
      {
        "symbol" => [
          { "symbolId" => 1001, "symbolName" => "GBPUSD", "enabled" => true }
        ]
      }
    end

    def reconcile(ctid_trader_account_id:)
      calls << [ :reconcile, ctid_trader_account_id ]
      {
        "position" => [
          {
            "positionId" => 77,
            "usedMargin" => 100_00,
            "moneyDigits" => 2
          }
        ],
        "order" => [
          {
            "orderId" => 88,
            "orderType" => "LIMIT"
          }
        ]
      }
    end

    def position_unrealized_pnl(ctid_trader_account_id:)
      calls << [ :unrealized_pnl, ctid_trader_account_id ]
      {
        "moneyDigits" => 2,
        "positionUnrealizedPnL" => [
          { "positionId" => 77, "netUnrealizedPnL" => 50_00 }
        ]
      }
    end

    def deals(ctid_trader_account_id:, from_timestamp:, to_timestamp:)
      calls << [ :deals, ctid_trader_account_id, from_timestamp, to_timestamp ]
      {
        "deal" => [ { "dealId" => 91, "commission" => -250, "moneyDigits" => 2 } ],
        "hasMore" => false
      }
    end

    def orders(ctid_trader_account_id:, from_timestamp:, to_timestamp:)
      calls << [ :orders, ctid_trader_account_id, from_timestamp, to_timestamp ]
      {
        "order" => [ { "orderId" => 88, "orderType" => "LIMIT" } ],
        "hasMore" => false
      }
    end

    def cash_flows(ctid_trader_account_id:, from_timestamp:, to_timestamp:)
      calls << [ :cash_flows, ctid_trader_account_id, from_timestamp, to_timestamp ]
      {
        "depositWithdraw" => [
          { "operationType" => "DEPOSIT", "balanceHistoryId" => from_timestamp }
        ]
      }
    end
  end

  setup do
    @family = families(:dylan_family)
    @gateway = FakeGateway.new

    Rails.configuration.x.ctrader.client_id = "client-id"
    Rails.configuration.x.ctrader.client_secret = "client-secret"

    @item = CtraderItem.create!(
      family: @family,
      name: "IC Markets cTrader",
      environment: "demo",
      oauth_access_token: "access-token",
      oauth_refresh_token: "refresh-token",
      oauth_token_expires_at: 1.hour.from_now
    )
  end

  teardown do
    Rails.configuration.x.ctrader.client_id = ENV["CTRADER_OPEN_API_CLIENT_ID"]
    Rails.configuration.x.ctrader.client_secret = ENV["CTRADER_OPEN_API_CLIENT_SECRET"]
  end

  test "imports only the matching environment and preserves provider facts as raw provenance" do
    from_time = Time.zone.parse("2026-10-01 00:00:00")
    to_time = Time.zone.parse("2026-10-09 00:00:00")
    observed_at = Time.zone.parse("2026-10-09 00:05:00")

    accounts = @item.import_read_only_snapshot!(
      gateway: @gateway,
      from_timestamp: from_time,
      to_timestamp: to_time,
      observed_at: observed_at
    )

    assert_equal 1, accounts.size
    account = accounts.first

    assert_equal 123_456, account.ctid_trader_account_id
    assert_equal "IC Markets Global", account.broker_name
    assert_equal "GBP", account.currency
    assert_equal BigDecimal("1000"), account.balance
    assert_equal BigDecimal("1050"), account.equity
    assert_equal BigDecimal("100"), account.used_margin
    assert_equal BigDecimal("950"), account.free_margin
    assert_equal "SCOPE_VIEW", @item.reload.permission_scope
    assert_equal "ic_markets", account.certification_institution_key

    records = RawSourceRecord.where(
      family_id: @family.id,
      source_system: "ctrader"
    ).order(:record_type)

    assert_equal 6, records.count
    assert_equal %w[
      account_snapshot cash_flows historical_deals historical_orders open_positions pending_orders
    ], records.pluck(:record_type).sort
    assert records.all? { |record| record.metadata.fetch("permission_scope") == "SCOPE_VIEW" }
    assert records.none? { |record| record.payload.to_json.include?("access-token") }

    # No canonical Sure account is mutated merely because cTrader returned a snapshot.
    assert_nil account.current_account
  end

  test "normalizes Time inputs to Unix milliseconds and chunks cash flow history to seven days" do
    from_time = Time.zone.parse("2026-10-01 00:00:00")
    to_time = Time.zone.parse("2026-10-09 00:00:00")

    @item.import_read_only_snapshot!(
      gateway: @gateway,
      from_timestamp: from_time,
      to_timestamp: to_time
    )

    deal_call = @gateway.calls.find { |row| row.first == :deals }
    assert_equal (from_time.to_f * 1000).to_i, deal_call.fetch(2)
    assert_equal (to_time.to_f * 1000).to_i, deal_call.fetch(3)

    cash_calls = @gateway.calls.select { |row| row.first == :cash_flows }
    assert_equal 2, cash_calls.size
    assert_operator cash_calls.first.fetch(3) - cash_calls.first.fetch(2), :<=, 7.days.in_milliseconds
    assert_equal cash_calls.first.fetch(3) + 1, cash_calls.second.fetch(2)
  end

  test "rejects account rows with an unknown live/demo environment" do
    gateway = Class.new(FakeGateway) do
      def list_accounts!(access_token:)
        {
          "permission_scope" => "SCOPE_VIEW",
          "accounts" => [
            { "ctidTraderAccountId" => 123_456, "brokerTitleShort" => "IC Markets Global" }
          ]
        }
      end
    end.new

    error = assert_raises(Provider::Ctrader::Error) do
      @item.import_read_only_snapshot!(
        gateway: gateway,
        from_timestamp: Time.current - 1.day,
        to_timestamp: Time.current
      )
    end

    assert_includes error.message, "environment is missing"
    assert_nil @item.reload.last_synced_at
  end

  test "provider factory registers cTrader without exposing a public connection config" do
    assert Provider::Factory.registered?("CtraderAccount")
    assert_equal [], Provider::CtraderAdapter.connection_configs(family: @family)
  end
end

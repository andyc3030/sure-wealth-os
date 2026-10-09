# frozen_string_literal: true

class CtraderItem::Importer
  CASH_FLOW_MAX_WINDOW = 7.days

  def initialize(ctrader_item, gateway:)
    @ctrader_item = ctrader_item
    @gateway = gateway
  end

  def import(from_timestamp:, to_timestamp:, observed_at: Time.current)
    raise Provider::Ctrader::ConfigurationError, "cTrader Open API is not configured" unless Provider::Ctrader.configured?
    raise Provider::Ctrader::AuthenticationError, "cTrader item has no active OAuth token" unless ctrader_item.oauth_token_active?

    gateway.authenticate_application!(
      client_id: Provider::Ctrader.client_id,
      client_secret: Provider::Ctrader.client_secret
    )
    account_list = gateway.list_accounts!(access_token: ctrader_item.oauth_access_token)
    accounts = account_list.fetch("accounts").select { |row| environment_matches?(row) }

    ctrader_item.update!(
      permission_scope: account_list.fetch("permission_scope"),
      raw_accounts_payload: accounts,
      last_synced_at: observed_at,
      status: :good
    )

    accounts.map do |account_row|
      import_account(
        account_row,
        from_timestamp: from_timestamp.to_i,
        to_timestamp: to_timestamp.to_i,
        observed_at: observed_at
      )
    end
  rescue Provider::Ctrader::PermissionError, Provider::Ctrader::AuthenticationError
    ctrader_item.update!(status: :requires_update)
    raise
  end

  private

    attr_reader :ctrader_item, :gateway

    def import_account(account_row, from_timestamp:, to_timestamp:, observed_at:)
      row = account_row.to_h.stringify_keys
      account_id = Integer(row.fetch("ctidTraderAccountId"))

      gateway.authenticate_account!(
        ctid_trader_account_id: account_id,
        access_token: ctrader_item.oauth_access_token
      )

      trader = gateway.trader(ctid_trader_account_id: account_id)
      assets = gateway.asset_list(ctid_trader_account_id: account_id)
      reconciliation = gateway.reconcile(ctid_trader_account_id: account_id)
      pnl = gateway.position_unrealized_pnl(ctid_trader_account_id: account_id)
      deals = gateway.deals(
        ctid_trader_account_id: account_id,
        from_timestamp: from_timestamp,
        to_timestamp: to_timestamp
      )
      orders = gateway.orders(
        ctid_trader_account_id: account_id,
        from_timestamp: from_timestamp,
        to_timestamp: to_timestamp
      )
      cash_flows = fetch_cash_flows(
        account_id,
        from_timestamp: from_timestamp,
        to_timestamp: to_timestamp
      )

      currency = deposit_currency(trader, assets)
      balance = monetary_value(trader["balance"], trader["moneyDigits"])
      net_unrealized_pnl = Array(pnl["positionUnrealizedPnL"]).sum(BigDecimal("0")) do |position|
        monetary_value(position["netUnrealizedPnL"], pnl["moneyDigits"])
      end
      positions = Array(reconciliation["position"])
      current_orders = Array(reconciliation["order"])
      used_margin = positions.sum(BigDecimal("0")) do |position|
        monetary_value(position["usedMargin"], position["moneyDigits"] || trader["moneyDigits"])
      end
      equity = balance + net_unrealized_pnl

      account = ctrader_item.ctrader_accounts.find_or_initialize_by(
        ctid_trader_account_id: account_id
      )
      account.assign_attributes(
        trader_login: row["traderLogin"] || trader["traderLogin"],
        is_live: ActiveModel::Type::Boolean.new.cast(row["isLive"]),
        broker_name: row["brokerTitleShort"].presence || trader["brokerName"],
        currency: currency,
        money_digits: trader["moneyDigits"],
        balance: balance,
        equity: equity,
        used_margin: used_margin,
        free_margin: equity - used_margin,
        raw_payload: sanitize(
          "account" => row,
          "trader" => trader,
          "assets" => assets,
          "unrealized_pnl" => pnl
        ),
        raw_positions_payload: sanitize(positions),
        raw_orders_payload: sanitize(current_orders.presence || Array(orders["order"])),
        raw_deals_payload: sanitize(Array(deals["deal"])),
        raw_cash_flows_payload: sanitize(cash_flows),
        last_synced_at: observed_at
      )
      account.save!

      capture_raw_source_records!(
        account,
        observed_at: observed_at,
        orders: orders
      )

      account
    end

    def capture_raw_source_records!(ctrader_account, observed_at:, orders:)
      family = ctrader_item.family
      linked = ctrader_account.current_account
      account_provider = ctrader_account.account_provider

      {
        "account_snapshot" => ctrader_account.raw_payload,
        "open_positions" => ctrader_account.raw_positions_payload,
        "pending_orders" => ctrader_account.raw_orders_payload,
        "historical_orders" => sanitize(Array(orders["order"])),
        "historical_deals" => ctrader_account.raw_deals_payload,
        "cash_flows" => ctrader_account.raw_cash_flows_payload
      }.each do |record_type, payload|
        RawSourceRecord.ingest!(
          family: family,
          account: linked,
          account_provider: account_provider,
          source_system: "ctrader",
          record_type: record_type,
          source_key: "#{ctrader_account.ctid_trader_account_id}:#{record_type}",
          payload: payload,
          observed_at: observed_at,
          metadata: {
            "environment" => ctrader_item.environment,
            "permission_scope" => ctrader_item.permission_scope,
            "broker_name" => ctrader_account.broker_name
          }.compact
        )
      end
    end

    def fetch_cash_flows(account_id, from_timestamp:, to_timestamp:)
      return [] if to_timestamp < from_timestamp

      rows = []
      cursor = from_timestamp
      max_window_ms = CASH_FLOW_MAX_WINDOW.in_milliseconds.to_i

      while cursor <= to_timestamp
        window_end = [ cursor + max_window_ms, to_timestamp ].min
        response = gateway.cash_flows(
          ctid_trader_account_id: account_id,
          from_timestamp: cursor,
          to_timestamp: window_end
        )
        rows.concat(Array(response["depositWithdraw"]))
        break if window_end == to_timestamp

        cursor = window_end + 1
      end

      rows
    end

    def environment_matches?(row)
      is_live = ActiveModel::Type::Boolean.new.cast(row.to_h.stringify_keys["isLive"])
      ctrader_item.live? ? is_live : !is_live
    end

    def deposit_currency(trader, assets)
      asset_id = trader["depositAssetId"]
      asset = Array(assets["asset"]).map { |row| row.to_h.stringify_keys }
        .find { |row| row["assetId"].to_s == asset_id.to_s }

      asset&.fetch("name", nil)&.upcase
    end

    def monetary_value(raw, digits)
      return BigDecimal("0") if raw.nil?

      divisor = BigDecimal("10")**digits.to_i
      BigDecimal(raw.to_s) / divisor
    end

    def sanitize(value)
      case value
      when Hash
        value.to_h.each_with_object({}) do |(key, child), sanitized|
          normalized = key.to_s.downcase.delete("-_")
          next if %w[accesstoken refreshtoken clientsecret authorization].include?(normalized)

          sanitized[key.to_s] = sanitize(child)
        end
      when Array
        value.map { |child| sanitize(child) }
      else
        value
      end
    end
end

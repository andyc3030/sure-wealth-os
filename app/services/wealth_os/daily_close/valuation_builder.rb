# frozen_string_literal: true

module WealthOs
  module DailyClose
    class ValuationBuilder
      MissingBalanceError = Class.new(StandardError)

      Result = Data.define(:accounts, :gross_assets, :total_liabilities, :net_worth) do
        def as_json(*)
          {
            "accounts" => accounts,
            "gross_assets" => gross_assets.to_s("F"),
            "total_liabilities" => total_liabilities.to_s("F"),
            "net_worth" => net_worth.to_s("F")
          }
        end
      end

      def initialize(family:, close_date:, reporting_currency:, fx_resolver:)
        @family = family
        @close_date = close_date.to_date
        @reporting_currency = reporting_currency
        @fx_resolver = fx_resolver
      end

      def call
        accounts = family.accounts.visible.included_in_reports.includes(:accountable).order(:id).to_a
        balances = Balance.where(account_id: accounts.map(&:id), date: close_date).to_a
          .index_by { |balance| [ balance.account_id, balance.currency ] }

        rows = accounts.map do |account|
          balance = balances[[ account.id, account.currency ]]
          unless balance
            raise MissingBalanceError,
                  "missing exact #{close_date} balance for account #{account.id} (#{account.currency})"
          end

          fx = fx_resolver.resolve(from: account.currency, to: reporting_currency, date: close_date)
          reporting_value = balance.end_balance.to_d * fx.rate

          {
            "account_id" => account.id,
            "balance_id" => balance.id,
            "balance_date" => balance.date.iso8601,
            "name" => account.name,
            "classification" => account.classification,
            "accountable_type" => account.accountable_type,
            "subtype" => account.subtype,
            "currency" => account.currency,
            "native_value" => balance.end_balance.to_d.to_s("F"),
            "reporting_currency" => reporting_currency,
            "reporting_value" => reporting_value.to_s("F"),
            "fx" => fx.as_json
          }
        end

        assets = rows.select { |row| row.fetch("classification") == "asset" }
          .sum(BigDecimal("0")) { |row| row.fetch("reporting_value").to_d }
        liabilities = rows.select { |row| row.fetch("classification") == "liability" }
          .sum(BigDecimal("0")) { |row| row.fetch("reporting_value").to_d }

        Result.new(rows.freeze, assets, liabilities, assets - liabilities)
      end

      private

        attr_reader :family, :close_date, :reporting_currency, :fx_resolver
    end
  end
end

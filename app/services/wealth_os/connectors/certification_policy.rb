# frozen_string_literal: true

module WealthOs
  module Connectors
    class CertificationPolicy
      Profile = Data.define(:route_type, :expected_scope, :required_checks, :review_interval_days)

      PROFILES = {
        "plaid_uk" => Profile.new(
          "open_banking",
          "transactions",
          %w[
            institution_identity balance transactions pending_posted currency stable_identifiers
            consent_expiry_observable revocation reconnect_deduplication statement_reconciliation
            no_payment_initiation
          ],
          90
        ),
        "snaptrade" => Profile.new(
          "aggregator_brokerage",
          "read",
          %w[
            institution_identity accounts balances positions activities cost_basis_handling
            distributions_fees corporate_actions reconnect_deduplication revocation freshness
            no_trading_access
          ],
          90
        ),
        "ctrader" => Profile.new(
          "direct_api",
          "accounts",
          %w[
            institution_identity account_identity balance_equity positions pending_orders
            historical_deals commissions_swaps cash_flows permission_scope_view
            refresh_scope_preserved reconnect_deduplication revocation reconciliation
            no_trading_requests
          ],
          90
        ),
        "verified_manual" => Profile.new(
          "verified_manual",
          "manual",
          %w[
            official_document account_identity balance currency statement_date verification_timestamp
            reconciliation no_portal_scraping
          ],
          28
        )
      }.freeze

      class << self
        def profile!(provider_key)
          PROFILES.fetch(provider_key.to_s) do
            raise ArgumentError, "unsupported connector certification profile: #{provider_key}"
          end
        end

        def evaluate(provider_key:, observed_scope:, checks:)
          profile = profile!(provider_key)
          normalized = checks.to_h.stringify_keys
          missing = profile.required_checks.reject { |key| normalized[key] == true }
          scope_ok = observed_scope.to_s == profile.expected_scope

          {
            passed: scope_ok && missing.empty?,
            expected_scope: profile.expected_scope,
            missing_checks: missing,
            scope_matches: scope_ok
          }.freeze
        end
      end
    end
  end
end

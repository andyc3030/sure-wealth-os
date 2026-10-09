# frozen_string_literal: true

class Provider::CtraderAdapter < Provider::Base
  include Provider::InstitutionMetadata

  Provider::Factory.register("CtraderAccount", self)

  def self.supported_account_types
    %w[Investment]
  end

  # Phase 9 intentionally does not expose a public connection route.
  # Live UI activation is gated on completed production certification.
  def self.connection_configs(family:)
    []
  end

  def provider_name
    "ctrader"
  end

  def institution_name
    provider_account.broker_name.presence || "cTrader"
  end

  def institution_domain
    provider_account.broker_name.to_s.match?(/ic\s*markets/i) ? "icmarkets.com" : nil
  end

  def institution_url
    institution_domain ? "https://#{institution_domain}" : nil
  end

  def can_delete_holdings?
    false
  end
end

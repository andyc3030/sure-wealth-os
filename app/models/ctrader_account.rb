# frozen_string_literal: true

class CtraderAccount < ApplicationRecord
  include CurrencyNormalizable
  include Encryptable

  if encryption_ready?
    encrypts :raw_payload
    encrypts :raw_positions_payload
    encrypts :raw_orders_payload
    encrypts :raw_deals_payload
    encrypts :raw_cash_flows_payload
  end

  belongs_to :ctrader_item

  has_one :account_provider, as: :provider, dependent: :destroy
  has_one :linked_account, through: :account_provider, source: :account

  validates :ctid_trader_account_id, presence: true,
            uniqueness: { scope: :ctrader_item_id }
  validates :currency, length: { is: 3 }, allow_nil: true

  def current_account
    linked_account
  end

  def ensure_account_provider!(account)
    raise ArgumentError, "account is required" unless account
    raise ArgumentError, "account must belong to the same family" unless
      account.family_id == ctrader_item.family_id

    record = AccountProvider.find_or_initialize_by(
      provider_type: self.class.name,
      provider_id: id
    )
    record.account = account
    record.save!
    reload_account_provider
    record
  end

  def certification_institution_key
    return "ic_markets" if broker_name.to_s.match?(/ic\s*markets/i)

    broker_name.to_s.parameterize(separator: "_")
  end

  def production_certification(at: Time.current)
    return nil unless broker_name.present?

    WealthOs::Connectors::ProductionGate.call(
      family: ctrader_item.family,
      provider_key: "ctrader",
      institution_key: certification_institution_key,
      account: linked_account,
      at: at
    )
  end
end

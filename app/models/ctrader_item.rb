# frozen_string_literal: true

class CtraderItem < ApplicationRecord
  include Encryptable

  enum :environment, { demo: "demo", live: "live" }, default: :demo
  enum :status, { good: "good", requires_update: "requires_update" }, default: :good

  if encryption_ready?
    encrypts :oauth_access_token
    encrypts :oauth_refresh_token
    encrypts :raw_accounts_payload
  end

  belongs_to :family
  has_many :ctrader_accounts, dependent: :destroy

  validates :name, presence: true
  validates :permission_scope, inclusion: { in: [ "SCOPE_VIEW" ] }, allow_nil: true

  scope :active, -> { where(scheduled_for_deletion: false) }

  def apply_oauth_tokens!(payload)
    access_token = payload["accessToken"]
    refresh_token = payload["refreshToken"]
    raise ArgumentError, "cTrader token payload missing accessToken" if access_token.blank?
    raise ArgumentError, "cTrader token payload missing refreshToken" if refresh_token.blank?

    update!(
      oauth_access_token: access_token,
      oauth_refresh_token: refresh_token,
      oauth_token_expires_at: payload["expiresIn"].present? ?
        Time.current + payload["expiresIn"].to_i.seconds : oauth_token_expires_at
    )
  end

  def oauth_token_active?
    oauth_access_token.present? &&
      (oauth_token_expires_at.blank? || oauth_token_expires_at.future?)
  end

  def import_read_only_snapshot!(gateway: nil, from_timestamp:, to_timestamp:, observed_at: Time.current)
    owned_transport = nil
    if gateway.nil?
      owned_transport = Provider::Ctrader::JsonWebSocketTransport.new(environment: environment)
      gateway = Provider::Ctrader::ReadOnlyGateway.new(transport: owned_transport)
    end

    CtraderItem::Importer.new(self, gateway: gateway).import(
      from_timestamp: from_timestamp,
      to_timestamp: to_timestamp,
      observed_at: observed_at
    )
  ensure
    owned_transport&.close
  end
end

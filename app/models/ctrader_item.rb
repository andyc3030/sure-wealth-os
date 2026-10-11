# frozen_string_literal: true

class CtraderItem < ApplicationRecord
  include Encryptable
  include Syncable
  include DestroyableLater

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
  scope :syncable, -> { active.where.not(oauth_access_token: nil) }
  scope :ordered, -> { order(created_at: :desc) }
  scope :needs_update, -> { where(status: :requires_update) }

  def apply_oauth_tokens!(payload)
    access_token = payload["accessToken"]
    refresh_token = payload["refreshToken"]
    raise ArgumentError, "cTrader token payload missing accessToken" if access_token.blank?
    raise ArgumentError, "cTrader token payload missing refreshToken" if refresh_token.blank?

    update!(
      oauth_access_token: access_token,
      oauth_refresh_token: refresh_token,
      oauth_token_expires_at: payload["expiresIn"].present? ?
        Time.current + payload["expiresIn"].to_i.seconds : oauth_token_expires_at,
      permission_scope: nil
    )
  end

  def refresh_oauth_tokens!
    payload = Provider::Ctrader.refresh_tokens(refresh_token: oauth_refresh_token)
    apply_oauth_tokens!(payload)
  end

  def credentials_configured?
    oauth_access_token.present? && oauth_refresh_token.present?
  end

  def institution_display_name
    brokers = ctrader_accounts.where.not(broker_name: [ nil, "" ]).distinct.pluck(:broker_name)
    brokers.one? ? brokers.first : name
  end

  def institution_domain
    return "icmarkets.com" if institution_display_name.to_s.match?(/ic\s*markets/i)

    nil
  end

  def institution_url
    institution_domain ? "https://#{institution_domain}" : nil
  end

  def linked_accounts_count
    ctrader_accounts.joins(:account_provider).count
  end

  def total_accounts_count
    ctrader_accounts.count
  end

  def oauth_token_active?
    oauth_access_token.present? &&
      (oauth_token_expires_at.blank? || oauth_token_expires_at.future?)
  end

  def production_sync_approved?(at: Time.current)
    return true if demo?

    accounts = ctrader_accounts.to_a
    return false if accounts.empty?

    accounts.all? do |account|
      result = account.production_certification(at: at)
      result&.approved == true
    end
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

module Family::PlaidConnectable
  extend ActiveSupport::Concern

  InstitutionMismatch = Class.new(StandardError)
  REVOLUT_UK_INSTITUTION_ID = "ins_63"

  included do
    has_many :plaid_items, dependent: :destroy
  end

  def can_connect_plaid_us?
    plaid(:us).present?
  end

  # If Plaid provider is configured and user is in the EU region
  def can_connect_plaid_eu?
    plaid(:eu).present? && self.eu?
  end

  def create_plaid_item!(public_token:, item_name:, region:, expected_institution_id: nil)
    provider = plaid(region)
    public_token_response = provider.exchange_public_token(public_token)

    verify_expected_institution!(
      provider: provider,
      access_token: public_token_response.access_token,
      expected_institution_id: expected_institution_id
    )

    plaid_item = plaid_items.create!(
      name: item_name,
      plaid_id: public_token_response.item_id,
      access_token: public_token_response.access_token,
      plaid_region: region,
      owner: Current.user
    )

    plaid_item.sync_later

    plaid_item
  end

  def get_link_token(webhooks_url:, redirect_url:, accountable_type: nil, region: :us, access_token: nil, account_selection_enabled: false)
    return nil unless plaid(region)

    plaid(region).get_link_token(
      user_id: self.id,
      webhooks_url: webhooks_url,
      redirect_url: redirect_url,
      accountable_type: accountable_type,
      access_token: access_token,
      account_selection_enabled: account_selection_enabled
    ).link_token
  end

  private
    def verify_expected_institution!(provider:, access_token:, expected_institution_id:)
      return if expected_institution_id.blank?

      actual_institution_id = provider.get_item(access_token).item.institution_id.to_s
      return if ActiveSupport::SecurityUtils.secure_compare(
        actual_institution_id,
        expected_institution_id.to_s
      )

      begin
        provider.remove_item(access_token)
      rescue => e
        Rails.logger.warn("Failed to revoke mismatched Plaid item: #{e.class}: #{e.message}")
      end

      raise InstitutionMismatch,
            "Plaid institution mismatch: expected #{expected_institution_id}, got #{actual_institution_id.presence || 'blank'}"
    end

    def plaid(region)
      Provider::Registry.plaid_provider_for_region(region)
    end
end

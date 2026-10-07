# frozen_string_literal: true

require "digest"

class RawSourceRecord < ApplicationRecord
  FORBIDDEN_SECRET_KEYS = %w[
    access_token refresh_token bearer_token client_secret api_key api_secret
    password authorization private_key
  ].freeze
  belongs_to :family
  belongs_to :account, optional: true
  belongs_to :account_provider, optional: true

  has_many :source_identities, dependent: :nullify
  has_many :reconciliation_events, dependent: :nullify

  validates :source_system, :record_type, :source_key, :observed_at, :payload_sha256, presence: true
  validates :schema_version, numericality: { only_integer: true, greater_than: 0 }
  validate :payload_and_metadata_exclude_credentials

  before_validation :normalize_payload_and_digest, on: :create
  before_update :prevent_mutation
  before_destroy :prevent_mutation

  class << self
    def ingest!(family:, source_system:, record_type:, source_key:, payload:, observed_at: Time.current,
                effective_at: nil, account: nil, account_provider: nil, metadata: {}, schema_version: 1,
                idempotency_key: nil)
      normalized = canonicalize(payload)
      digest = digest_for(normalized)

      if idempotency_key.present?
        existing = find_by(
          family: family,
          source_system: source_system,
          idempotency_key: idempotency_key.to_s
        )
        return existing if existing
      end

      create!(
        family: family,
        source_system: source_system,
        record_type: record_type,
        source_key: source_key.to_s,
        idempotency_key: idempotency_key&.to_s,
        account: account,
        account_provider: account_provider,
        observed_at: observed_at,
        effective_at: effective_at,
        payload: normalized,
        payload_sha256: digest,
        metadata: canonicalize(metadata),
        schema_version: schema_version
      )
    rescue ActiveRecord::RecordNotUnique
      raise unless idempotency_key.present?

      find_by!(
        family: family,
        source_system: source_system,
        idempotency_key: idempotency_key.to_s
      )
    end

    def digest_for(payload)
      Digest::SHA256.hexdigest(JSON.generate(canonicalize(payload)))
    end

    def canonicalize(value)
      case value
      when Hash
        value.to_h
             .transform_keys(&:to_s)
             .sort
             .to_h
             .transform_values { |item| canonicalize(item) }
      when Array
        value.map { |item| canonicalize(item) }
      else
        value.as_json
      end
    end
  end

  private

    def payload_and_metadata_exclude_credentials
      forbidden = forbidden_keys_in(payload || {}) + forbidden_keys_in(metadata || {})
      return if forbidden.empty?

      errors.add(:base, "raw source records must not contain credential-like keys: #{forbidden.uniq.sort.join(", ")}")
    end

    def forbidden_keys_in(value)
      case value
      when Hash
        value.each_with_object([]) do |(key, nested), found|
          normalized = key.to_s.downcase.tr("-", "_")
          found << normalized if FORBIDDEN_SECRET_KEYS.include?(normalized)
          found.concat(forbidden_keys_in(nested))
        end
      when Array
        value.flat_map { |item| forbidden_keys_in(item) }
      else
        []
      end
    end

    def normalize_payload_and_digest
      self.payload = self.class.canonicalize(payload || {})
      self.metadata = self.class.canonicalize(metadata || {})
      self.payload_sha256 = self.class.digest_for(payload)
    end

    def prevent_mutation
      errors.add(:base, "raw source records are immutable")
      throw(:abort)
    end
end

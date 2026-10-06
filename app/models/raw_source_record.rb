# frozen_string_literal: true

require "digest"

class RawSourceRecord < ApplicationRecord
  belongs_to :family
  belongs_to :account, optional: true
  belongs_to :account_provider, optional: true

  has_many :source_identities, dependent: :nullify
  has_many :reconciliation_events, dependent: :nullify

  validates :source_system, :record_type, :source_key, :observed_at, :payload_sha256, presence: true
  validates :schema_version, numericality: { only_integer: true, greater_than: 0 }

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

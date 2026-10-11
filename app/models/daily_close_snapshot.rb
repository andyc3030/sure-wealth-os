# frozen_string_literal: true

class DailyCloseSnapshot < ApplicationRecord
  IdempotencyCollision = Class.new(StandardError)
  QUALITY_STATUSES = %w[pass warning].freeze

  belongs_to :family

  validates :close_date, :cutoff_at, :closed_at, :timezone, :reporting_currency,
            :quality_status, :payload_sha256, presence: true
  validates :reporting_currency, length: { is: 3 }
  validates :quality_status, inclusion: { in: QUALITY_STATUSES }
  validates :confidence, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 1 }
  validates :schema_version, numericality: { only_integer: true, greater_than: 0 }
  validates :close_date, uniqueness: { scope: :family_id }
  validate :closed_after_cutoff

  before_validation :normalize_payload_and_digest, on: :create
  before_update :prevent_mutation
  before_destroy :prevent_mutation

  class << self
    def capture!(family:, close_date:, cutoff_at:, closed_at:, timezone:, reporting_currency:,
                 quality_status:, confidence:, gross_assets:, total_liabilities:, net_worth:,
                 payload:, schema_version: 1)
      normalized = RawSourceRecord.canonicalize(payload)
      digest = RawSourceRecord.digest_for(normalized)

      existing = find_by(family: family, close_date: close_date)
      return verify_idempotent_replay!(
        existing,
        digest: digest,
        cutoff_at: cutoff_at,
        timezone: timezone,
        reporting_currency: reporting_currency,
        quality_status: quality_status,
        confidence: confidence,
        gross_assets: gross_assets,
        total_liabilities: total_liabilities,
        net_worth: net_worth,
        schema_version: schema_version
      ) if existing

      create!(
        family: family,
        close_date: close_date,
        cutoff_at: cutoff_at,
        closed_at: closed_at,
        timezone: timezone,
        reporting_currency: reporting_currency,
        quality_status: quality_status,
        confidence: confidence,
        gross_assets: gross_assets,
        total_liabilities: total_liabilities,
        net_worth: net_worth,
        payload: normalized,
        payload_sha256: digest,
        schema_version: schema_version
      )
    rescue ActiveRecord::RecordNotUnique
      existing = find_by!(family: family, close_date: close_date)
      verify_idempotent_replay!(
        existing,
        digest: digest,
        cutoff_at: cutoff_at,
        timezone: timezone,
        reporting_currency: reporting_currency,
        quality_status: quality_status,
        confidence: confidence,
        gross_assets: gross_assets,
        total_liabilities: total_liabilities,
        net_worth: net_worth,
        schema_version: schema_version
      )
    end

    private

      def verify_idempotent_replay!(record, digest:, cutoff_at:, timezone:, reporting_currency:,
                                    quality_status:, confidence:, gross_assets:, total_liabilities:,
                                    net_worth:, schema_version:)
        matches =
          record.payload_sha256 == digest &&
          record.cutoff_at == cutoff_at &&
          record.timezone == timezone &&
          record.reporting_currency == reporting_currency &&
          record.quality_status == quality_status &&
          record.confidence.to_d == confidence.to_d &&
          record.gross_assets.to_d == gross_assets.to_d &&
          record.total_liabilities.to_d == total_liabilities.to_d &&
          record.net_worth.to_d == net_worth.to_d &&
          record.schema_version == schema_version.to_i

        return record if matches

        raise IdempotencyCollision,
              "authoritative daily close already exists with different financial content"
      end
  end

  private

    def normalize_payload_and_digest
      self.payload = RawSourceRecord.canonicalize(payload || {})
      self.payload_sha256 = RawSourceRecord.digest_for(payload)
    end

    def closed_after_cutoff
      return if cutoff_at.blank? || closed_at.blank?
      return if closed_at >= cutoff_at

      errors.add(:closed_at, "must be at or after the configured cut-off")
    end

    def prevent_mutation
      errors.add(:base, "daily close snapshots are immutable")
      throw(:abort)
    end
end

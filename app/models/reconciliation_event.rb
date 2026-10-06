# frozen_string_literal: true

class ReconciliationEvent < ApplicationRecord
  KINDS = %w[balance cash position transaction duplicate source_conflict].freeze
  STATUSES = %w[passed warning failed].freeze

  belongs_to :family
  belongs_to :account, optional: true
  belongs_to :account_provider, optional: true
  belongs_to :subject, polymorphic: true, optional: true
  belongs_to :raw_source_record, optional: true

  validates :kind, inclusion: { in: KINDS }
  validates :status, inclusion: { in: STATUSES }
  validates :occurred_at, presence: true
  validates :currency, length: { is: 3 }, allow_nil: true
  validates :dedupe_key, uniqueness: { scope: :family_id }, allow_nil: true

  before_update :prevent_mutation
  before_destroy :prevent_mutation

  class << self
    def record_once!(family:, kind:, status:, expected:, actual:, difference:, occurred_at: Time.current,
                     dedupe_key: nil, account: nil, account_provider: nil, subject: nil, raw_source_record: nil,
                     material: false, tolerance: nil, currency: nil, details: {})
      if dedupe_key.present?
        existing = find_by(family: family, dedupe_key: dedupe_key)
        return existing if existing
      end

      create!(
        family: family,
        account: account,
        account_provider: account_provider,
        subject: subject,
        raw_source_record: raw_source_record,
        kind: kind,
        status: status,
        expected: expected,
        actual: actual,
        difference: difference,
        material: material,
        tolerance: tolerance,
        currency: currency,
        dedupe_key: dedupe_key,
        details: details,
        occurred_at: occurred_at
      )
    rescue ActiveRecord::RecordNotUnique
      find_by!(family: family, dedupe_key: dedupe_key)
    end
  end

  private

    def prevent_mutation
      errors.add(:base, "reconciliation events are append-only")
      throw(:abort)
    end
end

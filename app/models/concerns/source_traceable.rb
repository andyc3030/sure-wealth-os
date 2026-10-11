# frozen_string_literal: true

module SourceTraceable
  extend ActiveSupport::Concern

  included do
    belongs_to :raw_source_record, optional: true
    validate :raw_source_record_matches_account_scope
  end

  private

    def raw_source_record_matches_account_scope
      return if raw_source_record.nil? || account.nil?

      if raw_source_record.family_id != account.family_id
        errors.add(:raw_source_record, "must belong to the same family")
      end

      if raw_source_record.account_id.present? && raw_source_record.account_id != account_id
        errors.add(:raw_source_record, "must belong to the same account when account-scoped")
      end
    end
end

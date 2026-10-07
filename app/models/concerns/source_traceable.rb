# frozen_string_literal: true

module SourceTraceable
  extend ActiveSupport::Concern

  included do
    belongs_to :raw_source_record, optional: true
    validate :raw_source_record_matches_scope
  end

  private

    def raw_source_record_matches_scope
      return if raw_source_record.nil?

      expected_family_id =
        if respond_to?(:family_id) && family_id.present?
          family_id
        elsif respond_to?(:account) && account.present?
          account.family_id
        end

      if expected_family_id.present? && raw_source_record.family_id != expected_family_id
        errors.add(:raw_source_record, "must belong to the same family")
      end

      return unless respond_to?(:account_id)
      return if account_id.blank? || raw_source_record.account_id.blank?

      if raw_source_record.account_id != account_id
        errors.add(:raw_source_record, "must belong to the same account when account-scoped")
      end
    end
end

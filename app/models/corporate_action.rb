# frozen_string_literal: true

class CorporateAction < ApplicationRecord
  ACTION_TYPES = %w[
    split reverse_split merger spinoff rights ticker_change cash_dividend
    special_dividend return_of_capital fund_reorganization
  ].freeze
  STATUSES = %w[observed validated applied reconciled ignored].freeze
  RATIO_ACTIONS = %w[split reverse_split].freeze

  belongs_to :family
  belongs_to :account, optional: true
  belongs_to :security
  belongs_to :successor_security, class_name: "Security", optional: true
  belongs_to :raw_source_record, optional: true

  validates :canonical_key, :action_type, :status, :effective_date, presence: true
  validates :canonical_key, uniqueness: { scope: :family_id }
  validates :action_type, inclusion: { in: ACTION_TYPES }
  validates :status, inclusion: { in: STATUSES }
  validates :currency, length: { is: 3 }, allow_nil: true
  validates :ratio_numerator, :ratio_denominator,
            numericality: { greater_than: 0 }, allow_nil: true
  validate :ratio_present_for_split
  validate :family_scope_matches

  before_update :prevent_mutation
  before_destroy :prevent_mutation

  private

    def ratio_present_for_split
      return unless RATIO_ACTIONS.include?(action_type)
      return if ratio_numerator.present? && ratio_denominator.present?

      errors.add(:base, "split actions require numerator and denominator")
    end

    def family_scope_matches
      errors.add(:account, "must belong to the same family") if account && account.family_id != family_id
      if raw_source_record && raw_source_record.family_id != family_id
        errors.add(:raw_source_record, "must belong to the same family")
      end
    end

    def prevent_mutation
      errors.add(:base, "corporate actions are immutable in the Phase 4 foundation")
      throw(:abort)
    end
end

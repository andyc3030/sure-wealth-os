# frozen_string_literal: true

class CorporateAction < ApplicationRecord
  include SourceTraceable
  ACTION_TYPES = %w[
    stock_split reverse_split merger spinoff rights special_dividend
    return_of_capital symbol_change fund_merge
  ].freeze
  STATUSES = %w[pending confirmed cancelled].freeze
  SPLIT_TYPES = %w[stock_split reverse_split].freeze

  belongs_to :family
  belongs_to :security
  belongs_to :successor_security, class_name: "Security", optional: true

  validates :action_type, inclusion: { in: ACTION_TYPES }
  validates :status, inclusion: { in: STATUSES }
  validates :effective_date, presence: true
  validates :cash_amount, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :currency, length: { is: 3 }, allow_nil: true
  validate :split_ratio_present
  validate :confirmed_action_has_source_evidence

  before_update :prevent_confirmed_mutation
  before_destroy :prevent_confirmed_mutation

  scope :confirmed, -> { where(status: "confirmed") }
  scope :position_affecting, -> { confirmed.where(action_type: SPLIT_TYPES) }

  def split?
    SPLIT_TYPES.include?(action_type)
  end

  def ratio
    return nil unless split?
    return nil if ratio_numerator.blank? || ratio_denominator.blank?

    ratio_numerator.to_d / ratio_denominator.to_d
  end

  private

    def prevent_confirmed_mutation
      return unless status_in_database == "confirmed"

      errors.add(:base, "confirmed corporate actions are immutable")
      throw(:abort)
    end

    def confirmed_action_has_source_evidence
      return unless status == "confirmed"
      return if raw_source_record.present?

      errors.add(:raw_source_record, "is required before a corporate action can be confirmed")
    end

    def split_ratio_present
      return unless split?
      return if ratio_numerator.present? && ratio_denominator.present? &&
        ratio_numerator.to_d.positive? && ratio_denominator.to_d.positive?

      errors.add(:base, "split actions require a positive numerator and denominator")
    end
end

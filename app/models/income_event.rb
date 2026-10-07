# frozen_string_literal: true

class IncomeEvent < ApplicationRecord
  STATES = %w[forecast accrued declared received].freeze
  INCOME_TYPES = %w[dividend distribution interest coupon rent pension other].freeze
  ALLOWED_TRANSITIONS = {
    "forecast" => %w[accrued declared received],
    "accrued" => %w[received],
    "declared" => %w[received],
    "received" => []
  }.freeze

  belongs_to :family
  belongs_to :account, optional: true
  belongs_to :security, optional: true
  belongs_to :entry, optional: true
  belongs_to :raw_source_record, optional: true
  belongs_to :supersedes, class_name: "IncomeEvent", optional: true
  has_one :successor, class_name: "IncomeEvent", foreign_key: :supersedes_id, dependent: :nullify

  validates :event_key, :income_type, :state, :gross_amount, :net_amount, :currency, presence: true
  validates :state, inclusion: { in: STATES }
  validates :income_type, inclusion: { in: INCOME_TYPES }
  validates :currency, length: { is: 3 }
  validates :gross_amount, :withholding_tax_amount, :fee_amount, :net_amount,
            numericality: { greater_than_or_equal_to: 0 }
  validates :confidence,
            numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 1 },
            allow_nil: true

  validate :net_amount_matches_components
  validate :state_has_required_dates
  validate :ordinary_distribution_is_not_undeclared_accrual
  validate :associations_match_family
  validate :superseded_event_matches_identity

  before_validation :calculate_net_amount
  before_update :prevent_mutation
  before_destroy :prevent_mutation

  scope :current_versions, -> {
    where.not(id: where.not(supersedes_id: nil).select(:supersedes_id))
  }

  def transition_to!(new_state, **attributes)
    new_state = new_state.to_s
    unless ALLOWED_TRANSITIONS.fetch(state).include?(new_state)
      raise ArgumentError, "invalid income transition #{state} -> #{new_state}"
    end

    self.class.create!(
      attributes_for_successor.merge(attributes).merge(
        state: new_state,
        supersedes: self
      )
    )
  end

  def current_version?
    successor.nil?
  end

  private

    def attributes_for_successor
      attributes.slice(
        "family_id", "account_id", "security_id", "entry_id", "raw_source_record_id",
        "event_key", "income_type", "gross_amount", "withholding_tax_amount", "fee_amount",
        "net_amount", "amount_per_unit", "units_entitled", "currency", "expected_date",
        "declaration_date", "accrual_start_date", "accrual_end_date", "payment_date",
        "received_at", "forecast_method", "confidence", "source_method", "metadata"
      ).symbolize_keys
    end

    def calculate_net_amount
      return if gross_amount.nil?

      self.withholding_tax_amount ||= 0
      self.fee_amount ||= 0
      self.net_amount = gross_amount.to_d - withholding_tax_amount.to_d - fee_amount.to_d
    end

    def net_amount_matches_components
      return if [ gross_amount, withholding_tax_amount, fee_amount, net_amount ].any?(&:nil?)

      expected = gross_amount.to_d - withholding_tax_amount.to_d - fee_amount.to_d
      errors.add(:net_amount, "must equal gross less withholding tax and fees") unless net_amount.to_d == expected
    end

    def state_has_required_dates
      errors.add(:declaration_date, "is required for declared income") if state == "declared" && declaration_date.blank?
      errors.add(:accrual_end_date, "is required for accrued income") if state == "accrued" && accrual_end_date.blank?
      errors.add(:received_at, "is required for received income") if state == "received" && received_at.blank?
    end

    def ordinary_distribution_is_not_undeclared_accrual
      return unless state == "accrued" && income_type.in?(%w[dividend distribution])
      return if declaration_date.present?

      errors.add(:declaration_date, "is required before equity/fund distributions can be treated as accrued")
    end

    def associations_match_family
      [ account, raw_source_record ].compact.each do |record|
        errors.add(:base, "#{record.class.name} must belong to the same family") if record.family_id != family_id
      end

      errors.add(:entry, "must belong to the same family") if entry && entry.account.family_id != family_id
    end

    def superseded_event_matches_identity
      return if supersedes.nil?

      errors.add(:supersedes, "must belong to the same family") if supersedes.family_id != family_id
      errors.add(:event_key, "must match the superseded event") if supersedes.event_key != event_key
      errors.add(:income_type, "must match the superseded event") if supersedes.income_type != income_type
      errors.add(:currency, "must match the superseded event") if supersedes.currency != currency
    end

    def prevent_mutation
      errors.add(:base, "income events are append-only; create a successor state")
      throw(:abort)
    end
end

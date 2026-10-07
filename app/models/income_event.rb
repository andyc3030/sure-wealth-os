# frozen_string_literal: true

class IncomeEvent < ApplicationRecord
  STATES = %w[forecast accrued declared received].freeze
  INCOME_TYPES = %w[
    dividend interest coupon distribution rent salary pension annuity
    business_income other
  ].freeze
  CONFIDENCE_LEVELS = %w[confirmed high estimated low unknown].freeze

  ALLOWED_TRANSITIONS = {
    "forecast" => %w[forecast accrued declared received],
    "accrued" => %w[accrued declared received],
    "declared" => %w[declared received],
    "received" => %w[received]
  }.freeze

  REVISION_FIELDS = %w[
    gross_amount withholding_tax_amount fee_amount cash_received_amount currency expected_on
    accrual_start_date accrual_end_date declared_on payable_on received_on
    confidence source_system source_key metadata raw_source_record_id
  ].freeze

  belongs_to :family
  belongs_to :account, optional: true
  belongs_to :security, optional: true
  belongs_to :raw_source_record, optional: true

  has_many :transitions, class_name: "IncomeEventTransition", dependent: :delete_all

  validates :canonical_key, :state, :income_type, :currency, presence: true
  validates :canonical_key, uniqueness: { scope: :family_id }
  validates :state, inclusion: { in: STATES }
  validates :income_type, inclusion: { in: INCOME_TYPES }
  validates :confidence, inclusion: { in: CONFIDENCE_LEVELS }
  validates :currency, length: { is: 3 }
  validates :gross_amount, :withholding_tax_amount, :fee_amount,
            numericality: { greater_than_or_equal_to: 0 }
  validates :cash_received_amount, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validate :account_and_raw_source_match_family
  validate :state_dates_are_coherent

  before_validation :populate_received_cash, if: :received?
  after_create :record_initial_transition!
  before_update :prevent_untracked_mutation
  before_destroy :prevent_destroy

  def net_amount
    gross_amount.to_d - withholding_tax_amount.to_d - fee_amount.to_d
  end

  def transition_to!(new_state, attributes: {}, occurred_at: Time.current, reason: nil, raw_source_record: nil)
    target = new_state.to_s
    raise ArgumentError, "invalid income state: #{target}" unless STATES.include?(target)
    raise ArgumentError, "transition #{state} -> #{target} is not allowed" unless ALLOWED_TRANSITIONS.fetch(state).include?(target)

    attributes = attributes.to_h.stringify_keys
    unknown = attributes.keys - REVISION_FIELDS
    raise ArgumentError, "unsupported income revision fields: #{unknown.join(", ")}" if unknown.any?

    self.class.transaction do
      previous_state = state
      @transitioning = true
      assign_attributes(attributes)
      self.state = target
      self.raw_source_record = raw_source_record if raw_source_record
      save!

      transitions.create!(
        family: family,
        raw_source_record: raw_source_record || self.raw_source_record,
        from_state: previous_state,
        to_state: target,
        occurred_at: occurred_at,
        reason: reason,
        snapshot: transition_snapshot
      )
    ensure
      @transitioning = false
    end

    self
  end

  def received?
    state == "received"
  end

  def received_cash
    cash_received_amount.to_d
  end

  private

    def record_initial_transition!
      transitions.create!(
        family: family,
        raw_source_record: raw_source_record,
        from_state: nil,
        to_state: state,
        occurred_at: created_at || Time.current,
        reason: "created",
        snapshot: transition_snapshot
      )
    end

    def transition_snapshot
      {
        "state" => state,
        "income_type" => income_type,
        "gross_amount" => gross_amount.to_d.to_s("F"),
        "withholding_tax_amount" => withholding_tax_amount.to_d.to_s("F"),
        "fee_amount" => fee_amount.to_d.to_s("F"),
        "net_amount" => net_amount.to_s("F"),
        "cash_received_amount" => cash_received_amount&.to_d&.to_s("F"),
        "currency" => currency,
        "expected_on" => expected_on&.iso8601,
        "accrual_start_date" => accrual_start_date&.iso8601,
        "accrual_end_date" => accrual_end_date&.iso8601,
        "declared_on" => declared_on&.iso8601,
        "payable_on" => payable_on&.iso8601,
        "received_on" => received_on&.iso8601,
        "confidence" => confidence
      }
    end

    def populate_received_cash
      self.cash_received_amount = net_amount if cash_received_amount.nil?
    end

    def prevent_untracked_mutation
      return if @transitioning
      return if changes_to_save.empty?

      errors.add(:base, "income events must be changed through transition_to!")
      throw(:abort)
    end

    def prevent_destroy
      errors.add(:base, "income events are audit records and cannot be deleted individually")
      throw(:abort)
    end

    def account_and_raw_source_match_family
      if account && account.family_id != family_id
        errors.add(:account, "must belong to the same family")
      end
      if raw_source_record && raw_source_record.family_id != family_id
        errors.add(:raw_source_record, "must belong to the same family")
      end
    end

    def state_dates_are_coherent
      if state == "accrued" && (accrual_start_date.blank? || accrual_end_date.blank?)
        errors.add(:base, "accrued income requires accrual start and end dates")
      end
      if accrual_start_date && accrual_end_date && accrual_end_date < accrual_start_date
        errors.add(:accrual_end_date, "must be on or after accrual start date")
      end
      if state == "declared" && declared_on.blank?
        errors.add(:declared_on, "is required for declared income")
      end
      if state == "received" && received_on.blank?
        errors.add(:received_on, "is required for received income")
      end
    end
end

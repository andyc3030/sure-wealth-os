# frozen_string_literal: true

class IncomeEvent < ApplicationRecord
  include SourceTraceable
  STATES = %w[forecast accrued declared received].freeze
  TYPES = %w[dividend interest coupon distribution rent other].freeze
  CONFIDENCE_LEVELS = %w[confirmed high estimated low unknown].freeze
  ACCRUABLE_TYPES = %w[interest coupon rent].freeze

  TRANSITIONS = {
    "forecast" => %w[forecast accrued declared received],
    "accrued" => %w[accrued declared received],
    "declared" => %w[declared received],
    "received" => %w[received]
  }.freeze

  TRANSITION_ATTRIBUTES = %i[
    account security entry raw_source_record amount cash_amount tax_withheld fees
    effective_date declared_on ex_date payable_on accrual_start accrual_end
    source_system method confidence metadata
  ].freeze

  CASH_RECONCILIATION_TOLERANCE = BigDecimal("0.01")

  belongs_to :family
  belongs_to :account, optional: true
  belongs_to :security, optional: true
  belongs_to :entry, optional: true
  belongs_to :supersedes, class_name: "IncomeEvent", optional: true
  has_one :successor, class_name: "IncomeEvent", foreign_key: :supersedes_id

  validates :event_key, :income_type, :state, :currency, :effective_date, presence: true
  validates :income_type, inclusion: { in: TYPES }
  validates :state, inclusion: { in: STATES }
  validates :confidence, inclusion: { in: CONFIDENCE_LEVELS }
  validates :amount, :tax_withheld, :fees, :cash_amount,
            numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :currency, length: { is: 3 }
  validates :event_key,
            uniqueness: {
              scope: :family_id,
              conditions: -> { where(supersedes_id: nil) },
              message: "already has a lifecycle root"
            },
            if: -> { supersedes_id.nil? }
  validate :linked_account_matches_family
  validate :superseded_event_matches_identity
  validate :state_transition_is_allowed
  validate :accrued_state_matches_income_type
  validate :amount_required_before_received
  validate :received_cash_reconciles
  validate :cash_amount_only_when_received
  validate :entry_matches_income_account
  validate :received_state_has_evidence

  before_update :prevent_mutation
  before_destroy :prevent_mutation

  scope :current, -> {
    where.not(id: IncomeEvent.where.not(supersedes_id: nil).select(:supersedes_id))
  }

  class << self
    def current_for(family:, event_key:)
      current.find_by(family: family, event_key: event_key)
    end
  end

  def transition_to!(new_state, **attributes)
    attributes = attributes.symbolize_keys
    unknown = attributes.keys - TRANSITION_ATTRIBUTES
    raise ArgumentError, "unsupported income transition attributes: #{unknown.sort.join(", ")}" if unknown.any?

    defaults = {
      account: account,
      security: security,
      entry: entry,
      raw_source_record: raw_source_record,
      amount: amount,
      cash_amount: cash_amount,
      tax_withheld: tax_withheld,
      fees: fees,
      effective_date: effective_date,
      declared_on: declared_on,
      ex_date: ex_date,
      payable_on: payable_on,
      accrual_start: accrual_start,
      accrual_end: accrual_end,
      source_system: source_system,
      method: method,
      confidence: confidence,
      metadata: metadata
    }

    self.class.create!(
      defaults.merge(attributes).merge(
        family: family,
        supersedes: self,
        event_key: event_key,
        income_type: income_type,
        state: new_state.to_s,
        currency: currency
      )
    )
  end

  # The cash that actually landed, not the gross economic income.
  def received_cash
    return BigDecimal("0") unless state == "received"

    cash_amount.to_d
  end

  private

    def prevent_mutation
      errors.add(:base, "income event versions are immutable; create a successor")
      throw(:abort)
    end

    def linked_account_matches_family
      return if account.nil? || family.nil?

      errors.add(:account, "must belong to the same family") if account.family_id != family_id
    end

    def superseded_event_matches_identity
      return unless supersedes

      errors.add(:supersedes, "must belong to the same family") if supersedes.family_id != family_id
      errors.add(:event_key, "must match the superseded event") if supersedes.event_key != event_key
      errors.add(:income_type, "must match the superseded event") if supersedes.income_type != income_type
      errors.add(:currency, "must match the superseded event") if supersedes.currency != currency

      if supersedes.account_id.present? && supersedes.account_id != account_id
        errors.add(:account, "cannot change once assigned to an income lifecycle")
      end

      if supersedes.security_id.present? && supersedes.security_id != security_id
        errors.add(:security, "cannot change once assigned to an income lifecycle")
      end

      if supersedes.entry_id.present? && supersedes.entry_id != entry_id
        errors.add(:entry, "cannot change once assigned to an income lifecycle")
      end
    end

    def accrued_state_matches_income_type
      return unless state == "accrued"
      return if ACCRUABLE_TYPES.include?(income_type)

      errors.add(:state, "#{income_type} income must remain forecast until it is declared or received")
    end

    def state_transition_is_allowed
      return unless supersedes
      return if TRANSITIONS.fetch(supersedes.state, []).include?(state)

      errors.add(:state, "cannot transition from #{supersedes.state} to #{state}")
    end

    def amount_required_before_received
      return if state == "received" || amount.present?

      errors.add(:amount, "is required before income is received")
    end

    def cash_amount_only_when_received
      return if cash_amount.nil? || state == "received"

      errors.add(:cash_amount, "can only be recorded for received income")
    end

    def entry_matches_income_account
      return if entry.nil?

      errors.add(:entry, "must belong to the same family") if entry.account.family_id != family_id
      if account_id.present? && entry.account_id != account_id
        errors.add(:entry, "must belong to the income account")
      end
    end

    def received_state_has_evidence
      return unless state == "received"
      return if entry.present? || raw_source_record.present?

      errors.add(:base, "received income requires a booked entry or raw source record")
    end

    def received_cash_reconciles
      return unless state == "received"

      if cash_amount.nil?
        errors.add(:cash_amount, "is required for received income")
        return
      end

      if amount.nil?
        if tax_withheld.present? || fees.present?
          errors.add(:amount, "is required when withholding tax or fees are known")
        end
        return
      end

      known_deductions = [ tax_withheld, fees ].compact.sum(BigDecimal("0")) { |value| value.to_d }
      maximum_cash = amount.to_d - known_deductions

      if maximum_cash.negative?
        errors.add(:base, "known withholding tax plus fees cannot exceed gross income")
        return
      end

      if cash_amount.to_d > maximum_cash + CASH_RECONCILIATION_TOLERANCE
        errors.add(:cash_amount, "cannot exceed gross income less known deductions")
        return
      end

      return unless tax_withheld.present? && fees.present?
      return if (cash_amount.to_d - maximum_cash).abs <= CASH_RECONCILIATION_TOLERANCE

      errors.add(:cash_amount, "must equal gross income minus withholding tax and fees")
    end
end

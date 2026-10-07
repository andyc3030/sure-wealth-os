# frozen_string_literal: true

class IncomeEvent < ApplicationRecord
  include SourceTraceable
  STATES = %w[forecast accrued declared received].freeze
  TYPES = %w[dividend interest coupon distribution rent other].freeze
  CONFIDENCE_LEVELS = %w[confirmed high estimated low unknown].freeze

  TRANSITIONS = {
    "forecast" => %w[forecast accrued declared received],
    "accrued" => %w[accrued declared received],
    "declared" => %w[declared received],
    "received" => %w[received]
  }.freeze

  belongs_to :family
  belongs_to :account, optional: true
  belongs_to :security, optional: true
  belongs_to :supersedes, class_name: "IncomeEvent", optional: true
  has_one :successor, class_name: "IncomeEvent", foreign_key: :supersedes_id

  validates :event_key, :income_type, :state, :amount, :currency, :effective_date, presence: true
  validates :income_type, inclusion: { in: TYPES }
  validates :state, inclusion: { in: STATES }
  validates :confidence, inclusion: { in: CONFIDENCE_LEVELS }
  validates :amount, :tax_withheld, :fees, numericality: { greater_than_or_equal_to: 0 }
  validates :cash_amount, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :currency, length: { is: 3 }
  validates :event_key,
            uniqueness: {
              scope: :family_id,
              conditions: -> { where(supersedes_id: nil) },
              message: "already has a lifecycle root"
            },
            if: -> { supersedes_id.nil? }
  validate :superseded_event_matches_identity
  validate :state_transition_is_allowed

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
    self.class.create!(
      {
        family: family,
        account: account,
        security: security,
        raw_source_record: attributes.delete(:raw_source_record) || raw_source_record,
        supersedes: self,
        event_key: event_key,
        income_type: income_type,
        state: new_state.to_s,
        amount: amount,
        cash_amount: cash_amount,
        tax_withheld: tax_withheld,
        fees: fees,
        currency: currency,
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
      }.merge(attributes)
    )
  end

  # The cash that actually landed, not the gross economic income.
  def received_cash
    return BigDecimal("0") unless state == "received"

    (cash_amount || (amount - tax_withheld - fees)).to_d
  end

  private

    def prevent_mutation
      errors.add(:base, "income event versions are immutable; create a successor")
      throw(:abort)
    end

    def superseded_event_matches_identity
      return unless supersedes

      errors.add(:supersedes, "must belong to the same family") if supersedes.family_id != family_id
      errors.add(:event_key, "must match the superseded event") if supersedes.event_key != event_key
      errors.add(:income_type, "must match the superseded event") if supersedes.income_type != income_type
    end

    def state_transition_is_allowed
      return unless supersedes
      return if TRANSITIONS.fetch(supersedes.state, []).include?(state)

      errors.add(:state, "cannot transition from #{supersedes.state} to #{state}")
    end
end

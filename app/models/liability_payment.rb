# frozen_string_literal: true

class LiabilityPayment < ApplicationRecord
  PAYMENT_TYPES = %w[actual scheduled].freeze

  belongs_to :family
  belongs_to :account
  belongs_to :entry, optional: true
  belongs_to :raw_source_record, optional: true

  validates :canonical_key, :payment_date, :payment_type, :currency, presence: true
  validates :canonical_key, uniqueness: { scope: :family_id }
  validates :payment_type, inclusion: { in: PAYMENT_TYPES }
  validates :currency, length: { is: 3 }
  validates :total_amount, :principal_amount, :interest_amount, :fee_amount, :insurance_amount,
            numericality: { greater_than_or_equal_to: 0 }
  validate :loan_account_required
  validate :family_scope_matches
  validate :components_equal_total

  before_update :prevent_mutation
  before_destroy :prevent_mutation

  def financing_cost_amount
    interest_amount.to_d + fee_amount.to_d
  end

  def non_principal_cost_amount
    financing_cost_amount + insurance_amount.to_d
  end

  def self.build_from_schedule(loan:, payment_number:, canonical_key:, fees: 0, payment_type: "scheduled",
                               raw_source_record: nil, source_system: nil, source_key: nil)
    breakdown = loan.payment_breakdown(payment_number: payment_number)
    raise ArgumentError, "loan has no payment #{payment_number}" unless breakdown

    fee_amount = fees.to_d
    new(
      family: loan.account.family,
      account: loan.account,
      canonical_key: canonical_key,
      payment_date: breakdown.fetch(:date),
      payment_type: payment_type,
      principal_amount: breakdown.fetch(:principal).amount,
      interest_amount: breakdown.fetch(:interest).amount,
      fee_amount: fee_amount,
      insurance_amount: breakdown.fetch(:insurance).amount,
      total_amount: breakdown.fetch(:total).amount + fee_amount,
      currency: loan.account.currency,
      raw_source_record: raw_source_record,
      source_system: source_system,
      source_key: source_key
    )
  end

  private

    def loan_account_required
      return if account.nil?
      return if account.classification == "liability" && account.accountable_type == "Loan"

      errors.add(:account, "must be a loan liability account")
    end

    def family_scope_matches
      errors.add(:account, "must belong to the same family") if account && account.family_id != family_id
      if entry && entry.account.family_id != family_id
        errors.add(:entry, "must belong to the same family")
      end
      if raw_source_record && raw_source_record.family_id != family_id
        errors.add(:raw_source_record, "must belong to the same family")
      end
    end

    def components_equal_total
      expected = principal_amount.to_d + interest_amount.to_d + fee_amount.to_d + insurance_amount.to_d
      return if total_amount.to_d == expected

      errors.add(:total_amount, "must equal principal + interest + fees + insurance")
    end

    def prevent_mutation
      errors.add(:base, "liability payments are immutable")
      throw(:abort)
    end
end

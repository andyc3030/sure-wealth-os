# frozen_string_literal: true

class LiabilityPayment < ApplicationRecord
  include SourceTraceable
  STATES = %w[scheduled actual reconciled].freeze
  COMPONENT_TOLERANCE = BigDecimal("0.01")

  belongs_to :family
  belongs_to :account
  belongs_to :loan
  belongs_to :entry, optional: true

  validates :payment_date, :state, :total_amount, :currency, presence: true
  validates :state, inclusion: { in: STATES }
  validates :currency, length: { is: 3 }
  validates :total_amount, :principal_amount, :interest_amount, :fee_amount, :insurance_amount,
            numericality: { greater_than_or_equal_to: 0 }
  validate :loan_account_family_match
  validate :components_equal_total

  def financing_cost
    interest_amount.to_d + fee_amount.to_d
  end

  def insurance_cost
    insurance_amount.to_d
  end

  # Principal repayment reduces cash and debt by the same amount. It is not an
  # economic expense and therefore contributes zero to net-worth cost.
  def principal_net_worth_cost
    BigDecimal("0")
  end

  def net_worth_cost
    financing_cost + insurance_cost
  end

  private

    def loan_account_family_match
      return if loan.nil? || account.nil? || family.nil?

      loan_account = loan.account
      errors.add(:account, "must be the loan's account") unless loan_account&.id == account_id
      errors.add(:family, "must own the loan account") unless account.family_id == family_id
    end

    def components_equal_total
      return if total_amount.nil?

      components = principal_amount.to_d + interest_amount.to_d + fee_amount.to_d + insurance_amount.to_d
      return if (components - total_amount.to_d).abs <= COMPONENT_TOLERANCE

      errors.add(:total_amount, "must equal principal + interest + fees + insurance")
    end
end

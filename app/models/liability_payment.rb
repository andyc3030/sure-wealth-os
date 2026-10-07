# frozen_string_literal: true

class LiabilityPayment < ApplicationRecord
  KINDS = %w[scheduled actual].freeze

  belongs_to :family
  belongs_to :account
  belongs_to :entry, optional: true
  belongs_to :raw_source_record, optional: true

  validates :kind, inclusion: { in: KINDS }
  validates :payment_date, :total_amount, :principal_amount, :interest_amount, :fee_amount, :currency, presence: true
  validates :currency, length: { is: 3 }
  validates :total_amount, :principal_amount, :interest_amount, :fee_amount,
            numericality: { greater_than_or_equal_to: 0 }
  validates :dedupe_key, uniqueness: { scope: :family_id }, allow_nil: true

  validate :components_sum_to_total
  validate :account_is_family_liability
  validate :source_records_match_family

  before_update :prevent_mutation
  before_destroy :prevent_mutation

  def financing_cost_amount
    interest_amount.to_d + fee_amount.to_d
  end

  def principal_reduction_amount
    principal_amount.to_d
  end

  def self.from_schedule!(loan:, payment:, fee_amount: 0, source_method: "loan_amortization_schedule")
    account = loan.account
    raise ArgumentError, "loan must belong to an account" unless account

    total = payment.payment.amount.to_d + fee_amount.to_d

    create!(
      family: account.family,
      account: account,
      kind: "scheduled",
      payment_date: payment.date,
      payment_number: payment.number,
      total_amount: total,
      principal_amount: payment.principal.amount,
      interest_amount: payment.interest.amount,
      fee_amount: fee_amount,
      currency: account.currency,
      source_method: source_method,
      dedupe_key: "loan-schedule:#{account.id}:#{payment.number}:#{payment.date.iso8601}"
    )
  end

  private

    def components_sum_to_total
      return if [ total_amount, principal_amount, interest_amount, fee_amount ].any?(&:nil?)

      expected = principal_amount.to_d + interest_amount.to_d + fee_amount.to_d
      errors.add(:total_amount, "must equal principal + interest + fees") unless total_amount.to_d == expected
    end

    def account_is_family_liability
      return if account.nil? || family.nil?

      errors.add(:account, "must belong to the same family") if account.family_id != family_id
      errors.add(:account, "must be a liability account") unless account.classification == "liability"
    end

    def source_records_match_family
      errors.add(:raw_source_record, "must belong to the same family") if raw_source_record && raw_source_record.family_id != family_id
      errors.add(:entry, "must belong to the same family") if entry && entry.account.family_id != family_id
    end

    def prevent_mutation
      errors.add(:base, "liability payments are append-only")
      throw(:abort)
    end
end

# frozen_string_literal: true

class CorporateAction < ApplicationRecord
  ACTION_TYPES = %w[
    split reverse_split merger spinoff rights ticker_change cash_dividend
    special_dividend return_of_capital fund_reorganization
  ].freeze
  STATUSES = %w[observed validated applied reconciled ignored].freeze
  RATIO_ACTIONS = %w[split reverse_split].freeze
  POSITION_AFFECTING_STATUSES = %w[validated applied reconciled].freeze
  ALLOWED_STATUS_TRANSITIONS = {
    "observed" => %w[observed validated ignored],
    "validated" => %w[validated applied ignored],
    "applied" => %w[applied reconciled],
    "reconciled" => %w[reconciled],
    "ignored" => %w[ignored]
  }.freeze

  belongs_to :family
  belongs_to :account, optional: true
  belongs_to :security
  belongs_to :successor_security, class_name: "Security", optional: true
  belongs_to :raw_source_record, optional: true

  has_many :transitions, class_name: "CorporateActionTransition", dependent: :delete_all

  validates :canonical_key, :action_type, :status, :effective_date, presence: true
  validates :canonical_key, uniqueness: { scope: :family_id }
  validates :action_type, inclusion: { in: ACTION_TYPES }
  validates :status, inclusion: { in: STATUSES }
  validates :currency, length: { is: 3 }, allow_nil: true
  validates :ratio_numerator, :ratio_denominator,
            numericality: { greater_than: 0 }, allow_nil: true
  validate :ratio_present_for_split
  validate :family_scope_matches

  after_create :record_initial_transition!
  before_update :prevent_untracked_mutation
  before_destroy :prevent_destroy

  scope :position_affecting, -> {
    where(action_type: RATIO_ACTIONS, status: POSITION_AFFECTING_STATUSES)
  }

  def ratio
    return nil unless RATIO_ACTIONS.include?(action_type)
    return nil if ratio_numerator.blank? || ratio_denominator.blank?

    ratio_numerator.to_d / ratio_denominator.to_d
  end

  def transition_to!(new_status, occurred_at: Time.current, reason: nil, raw_source_record: nil)
    target = new_status.to_s
    raise ArgumentError, "invalid corporate-action status: #{target}" unless STATUSES.include?(target)
    unless ALLOWED_STATUS_TRANSITIONS.fetch(status).include?(target)
      raise ArgumentError, "transition #{status} -> #{target} is not allowed"
    end

    self.class.transaction do
      previous_status = status
      @transitioning = true
      self.status = target
      self.raw_source_record = raw_source_record if raw_source_record
      save!

      transitions.create!(
        family: family,
        raw_source_record: raw_source_record || self.raw_source_record,
        from_status: previous_status,
        to_status: target,
        occurred_at: occurred_at,
        reason: reason,
        snapshot: transition_snapshot
      )
    ensure
      @transitioning = false
    end

    self
  end

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

    def record_initial_transition!
      transitions.create!(
        family: family,
        raw_source_record: raw_source_record,
        from_status: nil,
        to_status: status,
        occurred_at: created_at || Time.current,
        reason: "created",
        snapshot: transition_snapshot
      )
    end

    def transition_snapshot
      {
        "status" => status,
        "action_type" => action_type,
        "effective_date" => effective_date&.iso8601,
        "ratio_numerator" => ratio_numerator&.to_d&.to_s("F"),
        "ratio_denominator" => ratio_denominator&.to_d&.to_s("F"),
        "cash_amount" => cash_amount&.to_d&.to_s("F"),
        "currency" => currency
      }
    end

    def prevent_untracked_mutation
      return if @transitioning
      return if changes_to_save.empty?

      errors.add(:base, "corporate actions must be changed through transition_to!")
      throw(:abort)
    end

    def prevent_destroy
      errors.add(:base, "corporate actions are audit records and cannot be deleted individually")
      throw(:abort)
    end
end

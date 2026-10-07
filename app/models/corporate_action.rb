# frozen_string_literal: true

class CorporateAction < ApplicationRecord
  ACTION_TYPES = %w[
    split reverse_split merger spinoff rights_issue special_dividend
    return_of_capital ticker_change security_change
  ].freeze
  STATUSES = %w[announced effective processed cancelled].freeze
  PROCESSING_MODES = %w[deterministic manual_review].freeze
  DETERMINISTIC_TYPES = %w[split reverse_split ticker_change security_change].freeze

  belongs_to :family
  belongs_to :security
  belongs_to :successor_security, class_name: "Security", optional: true
  belongs_to :raw_source_record, optional: true
  belongs_to :supersedes, class_name: "CorporateAction", optional: true
  has_one :successor, class_name: "CorporateAction", foreign_key: :supersedes_id, dependent: :nullify

  validates :action_key, :action_type, :status, :processing_mode, :effective_date, presence: true
  validates :action_type, inclusion: { in: ACTION_TYPES }
  validates :status, inclusion: { in: STATUSES }
  validates :processing_mode, inclusion: { in: PROCESSING_MODES }
  validates :ratio_numerator, :ratio_denominator, numericality: { greater_than: 0 }, allow_nil: true
  validates :cash_per_unit, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

  validate :split_has_ratio
  validate :deterministic_mode_is_supported
  validate :security_change_has_successor
  validate :source_matches_family
  validate :superseded_action_matches_identity

  before_update :prevent_mutation
  before_destroy :prevent_mutation

  scope :current_versions, -> {
    where.not(id: where.not(supersedes_id: nil).select(:supersedes_id))
  }

  def deterministic?
    processing_mode == "deterministic"
  end

  def supersede_with!(**attributes)
    self.class.create!(
      self.attributes.slice(
        "family_id", "security_id", "successor_security_id", "raw_source_record_id",
        "action_key", "action_type", "status", "processing_mode", "record_date",
        "effective_date", "payable_date", "ratio_numerator", "ratio_denominator",
        "cash_per_unit", "currency", "terms"
      ).symbolize_keys.merge(attributes).merge(supersedes: self)
    )
  end

  private

    def split_has_ratio
      return unless action_type.in?(%w[split reverse_split])
      return if ratio_numerator.present? && ratio_denominator.present?

      errors.add(:base, "split actions require numerator and denominator")
    end

    def deterministic_mode_is_supported
      return unless processing_mode == "deterministic"
      return if action_type.in?(DETERMINISTIC_TYPES)

      errors.add(:processing_mode, "is not supported deterministically for #{action_type}; manual review is required")
    end

    def security_change_has_successor
      return unless action_type.in?(%w[ticker_change security_change])
      return if successor_security.present?

      errors.add(:successor_security, "is required for security/ticker changes")
    end

    def source_matches_family
      return if raw_source_record.nil? || raw_source_record.family_id == family_id

      errors.add(:raw_source_record, "must belong to the same family")
    end

    def superseded_action_matches_identity
      return if supersedes.nil?

      errors.add(:supersedes, "must belong to the same family") if supersedes.family_id != family_id
      errors.add(:action_key, "must match the superseded action") if supersedes.action_key != action_key
    end

    def prevent_mutation
      errors.add(:base, "corporate actions are append-only; create a successor version")
      throw(:abort)
    end
end

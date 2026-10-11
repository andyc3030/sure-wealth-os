# frozen_string_literal: true

class SourceConflict < ApplicationRecord
  STATUSES = %w[open resolved ignored].freeze

  belongs_to :family
  belongs_to :account, optional: true
  belongs_to :subject, polymorphic: true, optional: true
  belongs_to :source_record_a, class_name: "RawSourceRecord"
  belongs_to :source_record_b, class_name: "RawSourceRecord"
  belongs_to :selected_source_record, class_name: "RawSourceRecord", optional: true

  validates :field_name, :detected_at, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :currency, length: { is: 3 }, allow_nil: true
  validate :records_belong_to_family
  validate :selected_record_is_conflict_side
  before_update :prevent_changes_after_resolution

  class << self
    def detect!(family:, field_name:, record_a:, record_b:, value_a:, value_b:, account: nil, subject: nil,
                selected_source_record: nil, impact_amount: nil, currency: nil, detected_at: Time.current)
      first, second = [ record_a, record_b ].sort_by { |record| record.id.to_s }
      first_value, second_value = first == record_a ? [ value_a, value_b ] : [ value_b, value_a ]

      find_by(
        family: family,
        source_record_a: first,
        source_record_b: second,
        field_name: field_name
      ) || create!(
        family: family,
        account: account,
        subject: subject,
        field_name: field_name,
        source_record_a: first,
        source_record_b: second,
        value_a: first_value,
        value_b: second_value,
        selected_source_record: selected_source_record,
        impact_amount: impact_amount,
        currency: currency,
        detected_at: detected_at
      )
    rescue ActiveRecord::RecordNotUnique
      find_by!(
        family: family,
        source_record_a: first,
        source_record_b: second,
        field_name: field_name
      )
    end
  end

  def resolve!(selected_source_record:, rule:)
    raise ActiveRecord::RecordInvalid.new(self) unless status == "open"
    raise ArgumentError, "selected source record must be one side of the conflict" unless
      [ source_record_a_id, source_record_b_id ].include?(selected_source_record.id)

    update!(
      status: "resolved",
      selected_source_record: selected_source_record,
      resolution_rule: rule,
      resolved_at: Time.current
    )
  end

  private

    def records_belong_to_family
      [ source_record_a, source_record_b, selected_source_record ].compact.each do |record|
        errors.add(:base, "source records must belong to the same family") if record.family_id != family_id
      end
    end

    def selected_record_is_conflict_side
      return if selected_source_record.nil?
      return if [ source_record_a_id, source_record_b_id ].include?(selected_source_record_id)

      errors.add(:selected_source_record, "must be one side of the conflict")
    end

    def prevent_changes_after_resolution
      return if status_in_database == "open"

      errors.add(:base, "resolved or ignored conflicts are immutable")
      throw(:abort)
    end
end

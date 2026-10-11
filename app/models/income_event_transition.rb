# frozen_string_literal: true

class IncomeEventTransition < ApplicationRecord
  belongs_to :family
  belongs_to :income_event
  belongs_to :raw_source_record, optional: true

  validates :to_state, :occurred_at, presence: true
  validates :to_state, inclusion: { in: IncomeEvent::STATES }
  validates :from_state, inclusion: { in: IncomeEvent::STATES }, allow_nil: true
  validate :family_scope_matches

  before_update :prevent_mutation
  before_destroy :prevent_mutation

  private

    def family_scope_matches
      errors.add(:income_event, "must belong to the same family") if income_event && income_event.family_id != family_id
      errors.add(:raw_source_record, "must belong to the same family") if raw_source_record && raw_source_record.family_id != family_id
    end

    def prevent_mutation
      errors.add(:base, "income event transitions are append-only")
      throw(:abort)
    end
end

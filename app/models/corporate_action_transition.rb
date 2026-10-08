# frozen_string_literal: true

class CorporateActionTransition < ApplicationRecord
  belongs_to :family
  belongs_to :corporate_action
  belongs_to :raw_source_record, optional: true

  validates :to_status, :occurred_at, presence: true
  validates :to_status, inclusion: { in: CorporateAction::STATUSES }
  validates :from_status, inclusion: { in: CorporateAction::STATUSES }, allow_nil: true
  validate :family_scope_matches

  before_update :prevent_mutation
  before_destroy :prevent_mutation

  private

    def family_scope_matches
      if corporate_action && corporate_action.family_id != family_id
        errors.add(:corporate_action, "must belong to the same family")
      end
      if raw_source_record && raw_source_record.family_id != family_id
        errors.add(:raw_source_record, "must belong to the same family")
      end
    end

    def prevent_mutation
      errors.add(:base, "corporate-action transitions are append-only")
      throw(:abort)
    end
end

# frozen_string_literal: true

class SourceAuthorityRule < ApplicationRecord
  belongs_to :family

  validates :record_type, :field_name, :source_system, presence: true
  validates :priority, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :source_system, uniqueness: { scope: [ :family_id, :record_type, :field_name ] }

  scope :active, -> { where(active: true) }
  scope :for_field, ->(family:, record_type:, field_name:) {
    active.where(family: family, record_type: record_type, field_name: field_name).order(:priority, :source_system)
  }
end

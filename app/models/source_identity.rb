# frozen_string_literal: true

class SourceIdentity < ApplicationRecord
  belongs_to :family
  belongs_to :raw_source_record, optional: true
  belongs_to :canonical, polymorphic: true
  belongs_to :supersedes, class_name: "SourceIdentity", optional: true

  validates :source_system, :entity_type, :external_id, :canonical_type, :canonical_id, presence: true
  validates :confidence, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 1 }

  before_update :prevent_mutation
  before_destroy :prevent_mutation

  scope :for_source_entity, ->(family:, source_system:, entity_type:, external_id:) {
    where(
      family: family,
      source_system: source_system,
      entity_type: entity_type,
      external_id: external_id
    )
  }

  class << self
    def resolve!(family:, source_system:, entity_type:, external_id:, canonical:, confidence: 1,
                 raw_source_record: nil, verified_at: Time.current)
      scope = for_source_entity(
        family: family,
        source_system: source_system,
        entity_type: entity_type,
        external_id: external_id.to_s
      )
      current = scope.order(created_at: :desc).first

      return current if current&.canonical_type == canonical.class.polymorphic_name &&
                        current&.canonical_id == canonical.id &&
                        current&.confidence == confidence.to_d

      create!(
        family: family,
        source_system: source_system,
        entity_type: entity_type,
        external_id: external_id.to_s,
        canonical: canonical,
        confidence: confidence,
        raw_source_record: raw_source_record,
        verified_at: verified_at,
        supersedes: current
      )
    end
  end

  private

    def prevent_mutation
      errors.add(:base, "source identity versions are immutable; create a superseding version")
      throw(:abort)
    end
end

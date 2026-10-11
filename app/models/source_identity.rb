# frozen_string_literal: true

class SourceIdentity < ApplicationRecord
  belongs_to :family
  belongs_to :raw_source_record, optional: true
  belongs_to :canonical, polymorphic: true
  belongs_to :supersedes, class_name: "SourceIdentity", optional: true

  validates :source_system, :entity_type, :external_id, :canonical_type, :canonical_id, presence: true
  validates :confidence, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 1 }
  validate :raw_source_record_matches_family
  validate :canonical_matches_family_when_scoped
  validate :superseded_identity_matches_source_entity
  validates :external_id,
            uniqueness: {
              scope: [ :family_id, :source_system, :entity_type ],
              conditions: -> { where(supersedes_id: nil) },
              message: "already has a root identity mapping"
            },
            if: -> { supersedes_id.nil? }

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
    rescue ActiveRecord::RecordNotUnique
      latest = scope.order(created_at: :desc).first
      return latest if latest&.canonical_type == canonical.class.polymorphic_name &&
                       latest&.canonical_id == canonical.id &&
                       latest&.confidence == confidence.to_d

      raise
    end
  end

  private

    def raw_source_record_matches_family
      return if raw_source_record.nil? || raw_source_record.family_id == family_id

      errors.add(:raw_source_record, "must belong to the same family")
    end

    def canonical_matches_family_when_scoped
      return if canonical.nil? || !canonical.respond_to?(:family_id) || canonical.family_id.blank?
      return if canonical.family_id == family_id

      errors.add(:canonical, "must belong to the same family")
    end

    def superseded_identity_matches_source_entity
      return if supersedes.nil?

      same_source_entity =
        supersedes.family_id == family_id &&
        supersedes.source_system == source_system &&
        supersedes.entity_type == entity_type &&
        supersedes.external_id == external_id

      errors.add(:supersedes, "must describe the same source entity") unless same_source_entity
    end

    def prevent_mutation
      errors.add(:base, "source identity versions are immutable; create a superseding version")
      throw(:abort)
    end
end

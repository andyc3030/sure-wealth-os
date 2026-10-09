# frozen_string_literal: true

class ConnectorCertification < ApplicationRecord
  ENVIRONMENTS = %w[sandbox demo production].freeze
  STATUSES = %w[passed failed].freeze
  SECRET_KEY_PATTERN =
    /(access[_-]?token|refresh[_-]?token|bearer[_-]?token|client[_-]?secret|api[_-]?(?:key|secret)|password|authorization[_-]?header|private[_-]?key|cookie)/i

  belongs_to :family
  belongs_to :account, optional: true
  belongs_to :supersedes, class_name: "ConnectorCertification", optional: true
  has_one :successor,
          class_name: "ConnectorCertification",
          foreign_key: :supersedes_id,
          dependent: :nullify,
          inverse_of: :supersedes

  validates :provider_key, :institution_key, :route_type, :environment, :status,
            :expected_scope, :observed_scope, :checked_at, :evidence_sha256, presence: true
  validates :environment, inclusion: { in: ENVIRONMENTS }
  validates :status, inclusion: { in: STATUSES }
  validates :evidence_sha256, format: { with: /\A[0-9a-f]{64}\z/ }
  validate :account_matches_family
  validate :superseded_record_matches_route
  validate :evidence_contains_no_secret_keys

  before_validation :normalize_evidence_and_digest, on: :create
  before_update :prevent_mutation
  before_destroy :prevent_mutation

  scope :latest_first, -> { order(checked_at: :desc, created_at: :desc, id: :desc) }

  def production_approved?(at: Time.current)
    passed? &&
      environment == "production" &&
      (review_due_at.nil? || review_due_at >= at)
  end

  def passed?
    status == "passed"
  end

  private

    def normalize_evidence_and_digest
      self.checks = RawSourceRecord.canonicalize(checks || {})
      self.evidence = RawSourceRecord.canonicalize(evidence || {})
      self.evidence_sha256 = RawSourceRecord.digest_for(evidence)
    end

    def account_matches_family
      return if account.nil? || account.family_id == family_id

      errors.add(:account, "must belong to the same family")
    end

    def superseded_record_matches_route
      return if supersedes.nil?
      return if supersedes.family_id == family_id &&
        supersedes.provider_key == provider_key &&
        supersedes.institution_key == institution_key &&
        supersedes.account_id == account_id

      errors.add(:supersedes, "must certify the same family/provider/institution/account route")
    end

    def evidence_contains_no_secret_keys
      paths = secret_paths(evidence || {})
      return if paths.empty?

      errors.add(:evidence, "must not contain secret-bearing keys: #{paths.join(", ")}")
    end

    def secret_paths(value, path = [])
      case value
      when Hash
        value.flat_map do |key, child|
          next_path = path + [ key.to_s ]
          matches = key.to_s.match?(SECRET_KEY_PATTERN) ? [ next_path.join(".") ] : []
          matches + secret_paths(child, next_path)
        end
      when Array
        value.each_with_index.flat_map { |child, index| secret_paths(child, path + [ index.to_s ]) }
      else
        []
      end
    end

    def prevent_mutation
      errors.add(:base, "connector certifications are immutable")
      throw(:abort)
    end
end

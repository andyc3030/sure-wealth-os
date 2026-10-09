# frozen_string_literal: true

class ConnectorCertification < ApplicationRecord
  ENVIRONMENTS = %w[sandbox demo production].freeze
  STATUSES = %w[passed failed].freeze
  SECRET_KEY_PATTERN = Regexp.union(
    /access[_-]?token/i,
    /refresh[_-]?token/i,
    /bearer[_-]?token/i,
    /client[_-]?secret/i,
    /api[_-]?(?:key|secret)/i,
    /password/i,
    /authorization[_-]?header/i,
    /private[_-]?key/i,
    /cookie/i
  ).freeze

  belongs_to :family
  belongs_to :account, optional: true
  belongs_to :reviewed_by, class_name: "User", optional: true
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
  validate :matches_deterministic_policy
  validate :review_horizon_is_bounded
  validate :production_reviewer_is_authorized

  before_validation :normalize_evidence_and_digest, on: :create
  before_update :prevent_mutation
  before_destroy :prevent_mutation

  scope :latest_first, -> { order(checked_at: :desc, created_at: :desc, id: :desc) }

  def production_approved?(at: Time.current)
    passed? &&
      environment == "production" &&
      reviewed_by.present? &&
      reviewed_by.family_id == family_id &&
      (reviewed_by.admin? || reviewed_by.super_admin?) &&
      review_due_at.present? &&
      review_due_at >= at
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
        supersedes.account_id == account_id &&
        supersedes.environment == environment

      errors.add(:supersedes, "must certify the same family/provider/institution/account/environment route")
    end

    def matches_deterministic_policy
      profile = WealthOs::Connectors::CertificationPolicy.profile!(provider_key)
      result = WealthOs::Connectors::CertificationPolicy.evaluate(
        provider_key: provider_key,
        observed_scope: observed_scope,
        checks: checks || {},
        evidence: evidence || {}
      )
      expected_status = result.fetch(:passed) ? "passed" : "failed"

      errors.add(:route_type, "must match certification policy") unless route_type == profile.route_type
      errors.add(:expected_scope, "must match certification policy") unless expected_scope == profile.expected_scope
      errors.add(:status, "must equal deterministic policy result #{expected_status}") unless status == expected_status
    rescue ArgumentError
      errors.add(:provider_key, "is not a supported certification profile")
    end

    def review_horizon_is_bounded
      return if checked_at.blank?

      profile = WealthOs::Connectors::CertificationPolicy.profile!(provider_key)
      if review_due_at.blank?
        errors.add(:review_due_at, "is required")
        return
      end

      errors.add(:review_due_at, "must be after checked_at") unless review_due_at > checked_at
      maximum = checked_at + profile.review_interval_days.days
      errors.add(:review_due_at, "cannot exceed policy review interval") if review_due_at > maximum
    rescue ArgumentError
      nil
    end

    def production_reviewer_is_authorized
      return unless environment == "production"

      if reviewed_by.nil?
        errors.add(:reviewed_by, "is required for production certification")
        return
      end

      errors.add(:reviewed_by, "must belong to the same family") unless reviewed_by.family_id == family_id
      unless reviewed_by.admin? || reviewed_by.super_admin?
        errors.add(:reviewed_by, "must be a family administrator")
      end
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

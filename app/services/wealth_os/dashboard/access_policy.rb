# frozen_string_literal: true

module WealthOs
  module Dashboard
    class AccessPolicy
      def self.allowed?(user:, family: nil)
        return false if user.blank?
        return false unless user.admin? || user.super_admin?

        family_id = family&.id || user.family_id
        user.family_id == family_id
      end
    end
  end
end

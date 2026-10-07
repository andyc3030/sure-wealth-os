# frozen_string_literal: true

module WealthOs
  module Accounting
    class CorporateActionProcessor
      ManualReviewRequired = Class.new(StandardError)
      Result = Data.define(:action_type, :quantity, :unit_cost, :security, :notes)

      def self.call(action:, quantity:, unit_cost:)
        new(action:, quantity:, unit_cost:).call
      end

      def initialize(action:, quantity:, unit_cost:)
        @action = action
        @quantity = quantity
        @unit_cost = unit_cost
      end

      def call
        raise ManualReviewRequired, "#{@action.action_type} requires manual review" unless @action.deterministic?

        case @action.action_type
        when "split", "reverse_split"
          split = CorporateAction::SplitAdjustment.call(
            quantity: @quantity,
            unit_cost: @unit_cost,
            numerator: @action.ratio_numerator,
            denominator: @action.ratio_denominator
          )
          Result.new(
            action_type: @action.action_type,
            quantity: split.quantity,
            unit_cost: split.unit_cost,
            security: @action.security,
            notes: { "total_cost_preserved" => split.total_cost.to_s("F") }
          )
        when "ticker_change", "security_change"
          Result.new(
            action_type: @action.action_type,
            quantity: @quantity.to_d,
            unit_cost: @unit_cost.to_d,
            security: @action.successor_security,
            notes: { "economic_value_change" => "none_by_identity_change_alone" }
          )
        else
          raise ManualReviewRequired, "#{@action.action_type} has no deterministic handler"
        end
      end
    end
  end
end

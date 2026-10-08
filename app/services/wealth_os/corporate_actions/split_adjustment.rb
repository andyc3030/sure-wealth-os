# frozen_string_literal: true

module WealthOs
  module CorporateActions
    class SplitAdjustment
      Result = Data.define(:quantity, :unit_cost, :total_cost, :ratio)

      def self.call(quantity:, unit_cost:, numerator:, denominator:)
        qty = quantity.to_d
        cost = unit_cost.to_d
        num = numerator.to_d
        den = denominator.to_d

        raise ArgumentError, "split numerator must be positive" unless num.positive?
        raise ArgumentError, "split denominator must be positive" unless den.positive?
        raise ArgumentError, "unit cost must be non-negative" if cost.negative?

        # Preserve exact rational arithmetic for common integer split ratios.
        # Calculating num / den first can introduce a repeating BigDecimal
        # approximation (for example 1/3), which then leaks into quantities.
        adjusted_quantity = (qty * num) / den
        adjusted_unit_cost = (cost * den) / num
        ratio = num / den

        Result.new(
          adjusted_quantity,
          adjusted_unit_cost,
          qty * cost,
          ratio
        )
      end

      def self.for_action(action, quantity:, unit_cost:)
        unless CorporateAction::RATIO_ACTIONS.include?(action.action_type)
          raise ArgumentError, "corporate action is not a split or reverse split"
        end

        call(
          quantity: quantity,
          unit_cost: unit_cost,
          numerator: action.ratio_numerator,
          denominator: action.ratio_denominator
        )
      end
    end
  end
end

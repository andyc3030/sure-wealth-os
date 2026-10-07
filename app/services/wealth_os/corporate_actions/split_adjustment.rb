# frozen_string_literal: true

module WealthOs
  module CorporateActions
    class SplitAdjustment
      Result = Data.define(:quantity, :cost_basis_per_unit, :total_cost_basis)

      def self.call(quantity:, numerator:, denominator:, cost_basis_per_unit: nil)
        numerator = numerator.to_d
        denominator = denominator.to_d
        raise ArgumentError, "split ratio must be positive" unless numerator.positive? && denominator.positive?

        ratio = numerator / denominator

        quantity = quantity.to_d
        adjusted_quantity = quantity * ratio

        if cost_basis_per_unit.nil?
          return Result.new(adjusted_quantity, nil, nil)
        end

        cost = cost_basis_per_unit.to_d
        adjusted_cost = cost / ratio
        Result.new(adjusted_quantity, adjusted_cost, quantity * cost)
      end
    end
  end
end

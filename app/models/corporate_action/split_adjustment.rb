# frozen_string_literal: true

class CorporateAction::SplitAdjustment
  Result = Data.define(:quantity, :unit_cost, :total_cost)

  def self.call(quantity:, unit_cost:, numerator:, denominator:)
    numerator = numerator.to_d
    denominator = denominator.to_d
    raise ArgumentError, "split numerator and denominator must be positive" unless numerator.positive? && denominator.positive?

    quantity = quantity.to_d
    unit_cost = unit_cost.to_d
    factor = numerator / denominator

    adjusted_quantity = quantity * factor
    adjusted_unit_cost = unit_cost / factor

    Result.new(
      quantity: adjusted_quantity,
      unit_cost: adjusted_unit_cost,
      total_cost: adjusted_quantity * adjusted_unit_cost
    )
  end
end

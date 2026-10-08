# frozen_string_literal: true

class Portfolio::Twr
  InvalidSubperiodError = Class.new(StandardError)

  Subperiod = Data.define(:opening_value, :closing_value, :external_flow, :flow_timing)

  attr_reader :subperiods

  def initialize(subperiods)
    @subperiods = Array(subperiods).map { |period| normalize(period) }.freeze
    raise ArgumentError, "at least one subperiod is required" if @subperiods.empty?
  end

  def self.rate(subperiods)
    new(subperiods).rate
  end

  def rate
    growth = subperiods.reduce(BigDecimal("1")) do |product, period|
      product * (BigDecimal("1") + subperiod_rate(period))
    end
    growth - 1
  end

  def subperiod_rates
    subperiods.map { |period| subperiod_rate(period) }
  end

  private

    def normalize(period)
      return period if period.is_a?(Subperiod)

      attributes = period.respond_to?(:to_h) ? period.to_h : {}
      Subperiod.new(
        attributes.fetch(:opening_value),
        attributes.fetch(:closing_value),
        attributes.fetch(:external_flow, 0),
        attributes.fetch(:flow_timing, :end)
      )
    end

    def subperiod_rate(period)
      opening = period.opening_value.to_d
      closing = period.closing_value.to_d
      flow = period.external_flow.to_d
      timing = period.flow_timing.to_sym

      case timing
      when :end
        denominator = opening
        numerator = closing - flow
      when :begin
        denominator = opening + flow
        numerator = closing
      when :none
        raise InvalidSubperiodError, "flow must be zero when flow_timing is none" unless flow.zero?

        denominator = opening
        numerator = closing
      else
        raise InvalidSubperiodError, "flow_timing must be begin, end or none"
      end

      raise InvalidSubperiodError, "TWR denominator must be positive" unless denominator.positive?

      (numerator / denominator) - 1
    end
end

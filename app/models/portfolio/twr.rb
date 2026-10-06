# frozen_string_literal: true

class Portfolio::Twr
  InvalidSegment = Class.new(StandardError)

  # external_flow is a contribution (+) or withdrawal (-) occurring at the end
  # of the subperiod. A true TWR caller must split the history at external-flow
  # boundaries; this class chains those subperiod returns.
  Segment = Data.define(:date, :begin_value, :end_value, :external_flow)

  attr_reader :segments

  def initialize(segments)
    @segments = Array(segments).map do |segment|
      segment.is_a?(Segment) ? segment : Segment.new(**segment)
    end.sort_by(&:date).freeze
  end

  def rate
    return nil if segments.empty?

    growth = segments.reduce(BigDecimal("1")) do |factor, segment|
      begin_value = segment.begin_value.to_d
      raise InvalidSegment, "begin_value must be positive" unless begin_value.positive?

      end_value = segment.end_value.to_d
      external_flow = segment.external_flow.to_d
      subperiod = (end_value - external_flow) / begin_value
      raise InvalidSegment, "subperiod growth factor must be non-negative" if subperiod.negative?

      factor * subperiod
    end

    growth - 1
  end

  def percent
    value = rate
    value && value * 100
  end
end

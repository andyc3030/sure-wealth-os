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

    raise InvalidSegment, "segment date is required" if @segments.any? { |segment| segment.date.nil? }

    dates = @segments.map(&:date)
    if dates.uniq.length != dates.length
      raise InvalidSegment, "multiple TWR segments on the same date are ambiguous"
    end
  end

  def rate
    return nil if segments.empty?

    growth = segments.reduce(BigDecimal("1")) do |factor, segment|
      begin_value = decimal!(segment.begin_value, "begin_value")
      raise InvalidSegment, "begin_value must be positive" unless begin_value.positive?

      end_value = decimal!(segment.end_value, "end_value")
      external_flow = decimal!(segment.external_flow, "external_flow")
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

  private

    def decimal!(value, name)
      raise InvalidSegment, "#{name} is required" if value.nil?

      decimal = value.to_d
      raise InvalidSegment, "#{name} must be finite" unless decimal.finite?

      decimal
    end
end

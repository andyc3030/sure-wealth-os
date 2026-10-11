# frozen_string_literal: true

class Portfolio::ModifiedDietz
  InvalidPeriodError = Class.new(StandardError)
  ZeroDenominatorError = Class.new(StandardError)

  Flow = Data.define(:date, :amount)

  attr_reader :opening_value, :closing_value, :start_date, :end_date, :flows

  def initialize(opening_value:, closing_value:, start_date:, end_date:, flows: [])
    @opening_value = opening_value.to_d
    @closing_value = closing_value.to_d
    @start_date = start_date.to_date
    @end_date = end_date.to_date
    @flows = Array(flows).map { |flow| normalize_flow(flow) }.freeze

    raise InvalidPeriodError, "end date must be after start date" unless @end_date > @start_date
    unless @flows.all? { |flow| flow.date >= @start_date && flow.date <= @end_date }
      raise InvalidPeriodError, "all flows must fall inside the measurement period"
    end
  end

  def self.rate(**args)
    new(**args).rate
  end

  def rate
    net_flow = flows.sum(BigDecimal("0")) { |flow| flow.amount.to_d }
    weighted_flow = flows.sum(BigDecimal("0")) do |flow|
      flow.amount.to_d * weight_for(flow.date)
    end

    denominator = opening_value + weighted_flow
    raise ZeroDenominatorError, "Modified Dietz denominator is zero" if denominator.zero?

    (closing_value - opening_value - net_flow) / denominator
  end

  private

    def normalize_flow(flow)
      return flow if flow.is_a?(Flow)

      attributes = flow.respond_to?(:to_h) ? flow.to_h : {}
      Flow.new(attributes.fetch(:date).to_date, attributes.fetch(:amount).to_d)
    end

    def weight_for(date)
      total_days = (end_date - start_date).to_i.to_d
      remaining_days = (end_date - date).to_i.to_d
      remaining_days / total_days
    end
end

# frozen_string_literal: true

class Portfolio::Twr
  NoPeriodsError = Class.new(StandardError)
  ZeroOpeningValueError = Class.new(StandardError)
  InvalidPeriodError = Class.new(StandardError)

  Subperiod = Data.define(:start_date, :end_date, :opening_value, :closing_value, :external_flow_at_end)
  Result = Data.define(:rate, :subperiod_rates)

  def self.rate(subperiods)
    new(subperiods).rate
  end

  def initialize(subperiods)
    @subperiods = Array(subperiods).map { |period| normalize(period) }
    raise NoPeriodsError, "at least one valuation subperiod is required" if @subperiods.empty?

    validate_periods!
  end

  def rate
    linked = subperiod_rates.reduce(BigDecimal("1")) { |product, value| product * (BigDecimal("1") + value) }
    linked - BigDecimal("1")
  end

  def result
    Result.new(rate: rate, subperiod_rates: subperiod_rates)
  end

  def subperiod_rates
    @subperiod_rates ||= @subperiods.map do |period|
      opening = period.opening_value.to_d
      raise ZeroOpeningValueError, "opening value must be positive" unless opening.positive?

      closing = period.closing_value.to_d
      flow = period.external_flow_at_end.to_d

      ((closing - flow) / opening) - BigDecimal("1")
    end
  end

  private

    def normalize(period)
      return period if period.is_a?(Subperiod)

      Subperiod.new(
        start_date: period.fetch(:start_date).to_date,
        end_date: period.fetch(:end_date).to_date,
        opening_value: period.fetch(:opening_value).to_d,
        closing_value: period.fetch(:closing_value).to_d,
        external_flow_at_end: period.fetch(:external_flow_at_end, 0).to_d
      )
    end

    def validate_periods!
      @subperiods.each do |period|
        raise InvalidPeriodError, "subperiod end must be after start" unless period.end_date > period.start_date
        raise InvalidPeriodError, "closing value cannot be negative" if period.closing_value.to_d.negative?
      end

      @subperiods.each_cons(2) do |previous, current|
        raise InvalidPeriodError, "subperiods overlap or are out of order" if current.start_date < previous.end_date
      end
    end
end

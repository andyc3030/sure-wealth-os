# frozen_string_literal: true

class IncomeEvent::Summary
  Bucket = Data.define(:state, :currency, :gross_amount, :net_amount, :event_count)

  def initialize(scope)
    @scope = scope
  end

  def buckets
    @scope.current_versions
          .group(:state, :currency)
          .pluck(
            :state,
            :currency,
            Arel.sql("COALESCE(SUM(gross_amount), 0)"),
            Arel.sql("COALESCE(SUM(net_amount), 0)"),
            Arel.sql("COUNT(*)")
          )
          .map do |state, currency, gross, net, count|
            Bucket.new(
              state: state,
              currency: currency,
              gross_amount: gross.to_d,
              net_amount: net.to_d,
              event_count: count.to_i
            )
          end
  end

  def for(state:, currency:)
    buckets.find { |bucket| bucket.state == state.to_s && bucket.currency == currency.to_s.upcase }
  end
end

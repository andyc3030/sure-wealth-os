# frozen_string_literal: true

module Holding::CorporateActionAdjustable
  private

    def corporate_actions_on(date)
      corporate_actions_by_date.fetch(date, EMPTY_ACTIONS)
    end

    def corporate_actions_by_date
      @corporate_actions_by_date ||= begin
        scope = CorporateAction.position_affecting
          .where(family_id: account.family_id, effective_date: account.start_date..Date.current)
          .order(:effective_date, :created_at, :id)
        scope = scope.where(security_id: @security_ids) if @security_ids.present?
        scope.to_a.group_by(&:effective_date)
      end
    end

    def corporate_action_dates
      corporate_actions_by_date.keys
    end

    def apply_corporate_actions_forward(portfolio, date, trackers: nil)
      adjusted = portfolio.dup

      corporate_actions_on(date).each do |action|
        ratio = action.ratio
        next unless ratio&.positive?

        security_id = action.security_id
        next unless adjusted.key?(security_id)

        adjusted[security_id] = adjusted[security_id].to_d * ratio
        trackers[security_id].apply_split(ratio) if trackers
      end

      adjusted
    end

    def apply_corporate_actions_reverse(portfolio, date)
      adjusted = portfolio.dup

      corporate_actions_on(date).reverse_each do |action|
        ratio = action.ratio
        next unless ratio&.positive?

        security_id = action.security_id
        next unless adjusted.key?(security_id)

        adjusted[security_id] = adjusted[security_id].to_d / ratio
      end

      adjusted
    end

    EMPTY_ACTIONS = [].freeze
end

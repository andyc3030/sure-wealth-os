# frozen_string_literal: true

module WealthOs
  class DailyCloseCoordinatorJob < ApplicationJob
    queue_as :scheduled

    def perform(now: Time.current)
      local_now = now.in_time_zone(DailyClose::Configuration::DEFAULT_TIMEZONE)

      prepare_families if prepare_sync_window?(local_now)

      finalize_families(
        now: now,
        close_date: DailyClose::Configuration.eligible_close_date(now: now)
      )
    end

    private

      def prepare_sync_window?(local_now)
        local_now.hour == 23 && local_now.min >= 30
      end

      def prepare_families
        Family.find_each do |family|
          next if Sync.any_incomplete_for?(family)

          family.sync_later
        rescue => error
          Rails.logger.error(
            "Wealth OS daily-close pre-sync failed for family #{family.id}: "             "#{error.class}: #{error.message}"
          )
        end
      end

      def finalize_families(now:, close_date:)
        Family.find_each do |family|
          next if DailyCloseSnapshot.exists?(family_id: family.id, close_date: close_date)

          DailyClose::Orchestrator.call(family: family, close_date: close_date, now: now)
        rescue DailyClose::Orchestrator::SyncInProgress,
               DailyClose::ValuationBuilder::MissingBalanceError,
               DailyClose::FxResolver::MissingRateError => error
          Rails.logger.warn(
            "Wealth OS daily close deferred for family #{family.id}: "             "#{error.class}: #{error.message}"
          )
        rescue DailyClose::Orchestrator::QualityGateFailed => error
          Rails.logger.error(
            "Wealth OS daily close blocked for family #{family.id}: "             "#{error.message}; quality=#{error.quality.as_json}; action_now=#{error.action_now}"
          )
        rescue => error
          Rails.logger.error(
            "Wealth OS daily close failed for family #{family.id}: "             "#{error.class}: #{error.message}"
          )
          raise
        end
      end
  end
end

# frozen_string_literal: true

module WealthOs
  class ProvenanceController < ApplicationController
    def show
      raise ActiveRecord::RecordNotFound unless Dashboard::AccessPolicy.allowed?(
        user: Current.user,
        family: Current.family
      )

      metric = params[:metric].to_s
      raise ActiveRecord::RecordNotFound unless Dashboard::ProvenanceBuilder::METRICS.include?(metric)

      @snapshot = DailyCloseSnapshot.find_by!(
        id: params[:snapshot_id],
        family_id: Current.family.id
      )
      @provenance = Dashboard::ProvenanceBuilder.call(snapshot: @snapshot, metric: metric)
      @breadcrumbs = [
        [ I18n.t("breadcrumbs.home"), root_path ],
        [ "Authoritative close provenance", nil ]
      ]
    end
  end
end

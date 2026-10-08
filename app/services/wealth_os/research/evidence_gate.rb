# frozen_string_literal: true

module WealthOs
  module Research
    class EvidenceGate
      MIN_SOURCES = 10
      MIN_PRIMARY_OR_INSTITUTIONAL = 2
      MIN_ACADEMIC = 1
      MIN_INDUSTRY = 1
      MIN_DISSENTING = 1
      MIN_COUNTER_THESIS_SOURCES = 3

      Result = Data.define(:passed, :deficiencies, :top_sources, :source_count, :challenging_source_count)

      def self.call(theme:, sources:, claims:)
        new(theme: theme, sources: sources, claims: claims).call
      end

      def initialize(theme:, sources:, claims:)
        @theme = theme
        @sources = Array(sources).select { |source| source.theme == theme && source.status == "accepted" }
        @claims = Array(claims).select { |claim| claim.theme == theme && claim.status == "accepted" }
      end

      def call
        deficiencies = []
        deficiencies << "fewer than #{MIN_SOURCES} accepted sources" if @sources.size < MIN_SOURCES
        deficiencies << "fewer than #{MIN_PRIMARY_OR_INSTITUTIONAL} primary/institutional sources" if count_types(ResearchSource::PRIMARY_OR_INSTITUTIONAL_TYPES) < MIN_PRIMARY_OR_INSTITUTIONAL
        deficiencies << "no accepted academic/research-institution source" if count_types(ResearchSource::ACADEMIC_TYPES) < MIN_ACADEMIC
        deficiencies << "no accepted high-quality industry source" if count_types(ResearchSource::INDUSTRY_TYPES) < MIN_INDUSTRY
        deficiencies << "no accepted dissenting source" if @sources.count(&:dissenting?) < MIN_DISSENTING

        challenging_source_ids = @claims.select { |claim| claim.thesis_effect == "challenges" }.map(&:research_source_id).uniq
        deficiencies << "fewer than #{MIN_COUNTER_THESIS_SOURCES} independent counter-thesis sources" if independent_source_count(challenging_source_ids) < MIN_COUNTER_THESIS_SOURCES

        cross_check_failures.each do |key|
          deficiencies << "material factual claim #{key.inspect} is not cross-checked by two independent sources"
        end

        Result.new(
          deficiencies.empty?,
          deficiencies,
          ranked_sources.first(5),
          @sources.size,
          independent_source_count(challenging_source_ids)
        )
      end

      private

        def count_types(types)
          @sources.count { |source| source.source_type.in?(types) }
        end

        def independent_source_count(source_ids)
          @sources.select { |source| source.id.in?(source_ids) }.map(&:independence_key).uniq.size
        end

        def cross_check_failures
          material_facts = @claims.select { |claim| claim.material? && claim.claim_type == "fact" }
          groups = material_facts.group_by(&:cross_check_key)

          material_facts.select { |claim| claim.cross_check_key.blank? }.map { |claim| "claim:#{claim.id}" } +
            groups.filter_map do |key, claims|
              sources = @sources.select { |source| source.id.in?(claims.map(&:research_source_id)) }
              key if sources.map(&:independence_key).uniq.size < 2
            end
        end

        def ranked_sources
          @sources.sort_by do |source|
            score = source.latest_overall_score || 0
            [ source.ranking_tier, -score.to_d, -(source.publication_date&.jd || 0) ]
          end
        end
    end
  end
end

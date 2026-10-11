# frozen_string_literal: true

class CreateResearchIntelligenceFoundation < ActiveRecord::Migration[8.1]
  SCORE_COLUMNS = %i[
    authority_score
    evidence_quality_score
    independence_score
    methodology_transparency_score
    relevance_score
    recency_score
    overall_score
  ].freeze

  def change
    create_table :research_sources, id: :uuid do |t|
      t.references :family, type: :uuid, null: false, foreign_key: { on_delete: :cascade }
      t.references :raw_source_record, type: :uuid, null: true, foreign_key: { on_delete: :nullify }
      t.string :theme, null: false
      t.string :title, null: false
      t.string :publisher, null: false
      t.text :url, null: false
      t.string :source_type, null: false
      t.date :publication_date
      t.datetime :accessed_at, null: false
      t.string :independence_group
      t.boolean :commercial_conflict, null: false, default: false
      t.text :conflict_notes
      t.boolean :promotional, null: false, default: false
      t.boolean :dissenting, null: false, default: false
      t.string :status, null: false, default: "accepted"
      t.text :notes
      t.timestamps
    end

    add_index :research_sources,
              [ :family_id, :theme, :publisher, :publication_date ],
              name: "idx_research_sources_theme_publisher_date"

    create_table :research_source_scores, id: :uuid do |t|
      t.references :family, type: :uuid, null: false, foreign_key: { on_delete: :cascade }
      t.references :research_source, type: :uuid, null: false, foreign_key: { on_delete: :cascade }
      t.date :as_of_date, null: false
      t.decimal :authority_score, precision: 3, scale: 2, null: false
      t.decimal :evidence_quality_score, precision: 3, scale: 2, null: false
      t.decimal :independence_score, precision: 3, scale: 2, null: false
      t.decimal :methodology_transparency_score, precision: 3, scale: 2, null: false
      t.decimal :relevance_score, precision: 3, scale: 2, null: false
      t.decimal :recency_score, precision: 3, scale: 2, null: false
      t.decimal :overall_score, precision: 3, scale: 2, null: false
      t.jsonb :rationale, null: false, default: {}
      t.timestamps
    end

    add_index :research_source_scores,
              [ :research_source_id, :as_of_date ],
              unique: true,
              name: "idx_research_source_scores_source_date"

    SCORE_COLUMNS.each do |column|
      add_check_constraint :research_source_scores,
                           "#{column} >= 0 AND #{column} <= 5",
                           name: "chk_research_source_scores_#{column}"
    end

    create_table :research_claims, id: :uuid do |t|
      t.references :family, type: :uuid, null: false, foreign_key: { on_delete: :cascade }
      t.references :research_source, type: :uuid, null: false, foreign_key: { on_delete: :cascade }
      t.references :raw_source_record, type: :uuid, null: true, foreign_key: { on_delete: :nullify }
      t.string :theme, null: false
      t.string :claim_type, null: false
      t.text :claim_summary, null: false
      t.string :locator
      t.boolean :material, null: false, default: false
      t.string :thesis_effect, null: false, default: "neutral"
      t.string :cross_check_key
      t.decimal :confidence, precision: 5, scale: 4
      t.datetime :verified_at
      t.string :status, null: false, default: "accepted"
      t.timestamps
    end

    add_index :research_claims,
              [ :family_id, :theme, :claim_type ],
              name: "idx_research_claims_theme_type"
    add_index :research_claims,
              [ :family_id, :cross_check_key ],
              name: "idx_research_claims_cross_check",
              where: "cross_check_key IS NOT NULL"
    add_check_constraint :research_claims,
                         "confidence IS NULL OR (confidence >= 0 AND confidence <= 1)",
                         name: "chk_research_claims_confidence"

    create_table :research_assessments, id: :uuid do |t|
      t.references :family, type: :uuid, null: false, foreign_key: { on_delete: :cascade }
      t.string :theme, null: false
      t.date :as_of_date, null: false
      t.string :methodology_version, null: false
      t.text :evidence_summary, null: false
      t.text :uncertainty, null: false
      t.text :falsification_conditions, null: false
      t.jsonb :structural_bottlenecks, null: false, default: []
      t.jsonb :quality_exposures, null: false, default: []
      t.jsonb :narrative_beneficiaries, null: false, default: []
      t.jsonb :portfolio_coverage, null: false, default: []
      t.jsonb :new_positions, null: false, default: []
      t.jsonb :top_source_ids, null: false, default: []
      t.integer :source_count, null: false, default: 0
      t.integer :challenging_source_count, null: false, default: 0
      t.boolean :insufficient_evidence, null: false, default: false
      t.timestamps
    end

    add_index :research_assessments,
              [ :family_id, :theme, :as_of_date, :methodology_version ],
              unique: true,
              name: "idx_research_assessments_version"

    create_table :investment_recommendations, id: :uuid do |t|
      t.references :family, type: :uuid, null: false, foreign_key: { on_delete: :cascade }
      t.references :research_assessment, type: :uuid, null: false, foreign_key: { on_delete: :cascade }
      t.string :action, null: false
      t.string :ticker
      t.string :company, null: false
      t.text :role_in_thesis
      t.decimal :reference_price, precision: 19, scale: 6
      t.string :price_currency, limit: 3
      t.datetime :price_as_of
      t.string :price_source
      t.decimal :entry_zone_low, precision: 19, scale: 6
      t.decimal :entry_zone_high, precision: 19, scale: 6
      t.decimal :invalidation_level, precision: 19, scale: 6
      t.text :structural_thesis
      t.text :near_term_catalyst
      t.jsonb :principal_risks, null: false, default: []
      t.text :correlation_context
      t.string :allocation_sleeve, null: false, default: "none"
      t.text :valuation_analysis
      t.text :competitive_position_analysis
      t.text :capital_intensity_analysis
      t.text :cash_generation_analysis
      t.text :balance_sheet_analysis
      t.text :downside_analysis
      t.decimal :evidence_quality_score, precision: 3, scale: 2
      t.string :technical_gate_status, null: false, default: "not_evaluated"
      t.jsonb :technical_gate_details, null: false, default: {}
      t.timestamps
    end

    add_index :investment_recommendations,
              [ :family_id, :action, :created_at ],
              name: "idx_investment_recommendations_action"
    add_check_constraint :investment_recommendations,
                         "evidence_quality_score IS NULL OR (evidence_quality_score >= 0 AND evidence_quality_score <= 5)",
                         name: "chk_investment_recommendations_evidence_quality"
  end
end

# frozen_string_literal: true

class CreateWealthOsResearchAdviceFoundation < ActiveRecord::Migration[8.1]
  def change
    create_table :research_runs, id: :uuid do |t|
      t.references :family, type: :uuid, null: false, foreign_key: { on_delete: :cascade }
      t.datetime :as_of_at, null: false
      t.string :methodology_version, null: false
      t.string :status, null: false, default: "draft"
      t.text :notes
      t.jsonb :metadata, null: false, default: {}
      t.timestamps
    end

    add_index :research_runs, [ :family_id, :as_of_at ], name: "idx_research_runs_family_as_of"

    create_table :research_sources, id: :uuid do |t|
      t.references :research_run, type: :uuid, null: false, foreign_key: { on_delete: :cascade }
      t.references :raw_source_record, type: :uuid, null: true, foreign_key: { on_delete: :nullify }
      t.string :theme, null: false
      t.string :source_type, null: false
      t.string :title, null: false
      t.string :publisher, null: false
      t.text :url, null: false
      t.date :publication_date
      t.datetime :retrieved_at, null: false
      t.integer :source_tier, null: false
      t.integer :authority, null: false
      t.integer :evidence_quality, null: false
      t.integer :independence, null: false
      t.integer :methodological_transparency, null: false
      t.integer :relevance, null: false
      t.integer :recency, null: false
      t.decimal :overall_quality_score, precision: 4, scale: 2, null: false
      t.string :thesis_position, null: false, default: "neutral"
      t.boolean :primary_or_institutional, null: false, default: false
      t.boolean :academic, null: false, default: false
      t.boolean :industry, null: false, default: false
      t.boolean :promotional, null: false, default: false
      t.boolean :commercial_conflict, null: false, default: false
      t.text :conflict_notes
      t.string :status, null: false, default: "accepted"
      t.string :content_sha256, limit: 64
      t.jsonb :metadata, null: false, default: {}
      t.timestamps
    end

    add_index :research_sources,
              [ :research_run_id, :theme, :url ],
              unique: true,
              name: "idx_research_sources_run_theme_url"
    add_index :research_sources,
              [ :research_run_id, :theme, :source_tier, :overall_quality_score ],
              name: "idx_research_sources_rank"

    create_table :research_claims, id: :uuid do |t|
      t.references :research_run, type: :uuid, null: false, foreign_key: { on_delete: :cascade }
      t.string :theme, null: false
      t.string :claim_kind, null: false
      t.text :statement, null: false
      t.string :stance, null: false, default: "neutral"
      t.boolean :important, null: false, default: false
      t.decimal :confidence, precision: 5, scale: 4
      t.string :status, null: false, default: "draft"
      t.text :falsification_criterion
      t.datetime :as_of_at, null: false
      t.jsonb :metadata, null: false, default: {}
      t.timestamps
    end

    add_index :research_claims,
              [ :research_run_id, :theme, :status ],
              name: "idx_research_claims_run_theme_status"

    create_table :research_evidences, id: :uuid do |t|
      t.references :research_claim, type: :uuid, null: false, foreign_key: { on_delete: :cascade }
      t.references :research_source, type: :uuid, null: false, foreign_key: { on_delete: :cascade }
      t.string :role, null: false
      t.text :evidence_summary, null: false
      t.string :pinpoint_reference
      t.boolean :independent, null: false, default: true
      t.decimal :weight, precision: 5, scale: 4, null: false, default: 1
      t.timestamps
    end

    add_index :research_evidences,
              [ :research_claim_id, :research_source_id, :role ],
              unique: true,
              name: "idx_research_evidences_unique"

    create_table :research_theme_assessments, id: :uuid do |t|
      t.references :research_run, type: :uuid, null: false, foreign_key: { on_delete: :cascade }
      t.string :theme, null: false
      t.text :evidence_summary, null: false
      t.text :uncertainty_summary, null: false
      t.jsonb :falsification_tests, null: false, default: []
      t.jsonb :structural_bottlenecks, null: false, default: []
      t.jsonb :highest_quality_exposures, null: false, default: []
      t.jsonb :narrative_only_beneficiaries, null: false, default: []
      t.text :existing_portfolio_exposure, null: false
      t.jsonb :missing_exposures, null: false, default: []
      t.string :status, null: false, default: "draft"
      t.timestamps
    end

    add_index :research_theme_assessments,
              [ :research_run_id, :theme ],
              unique: true,
              name: "idx_research_theme_assessments_unique"

    create_table :investment_recommendations, id: :uuid do |t|
      t.references :research_run, type: :uuid, null: false, foreign_key: { on_delete: :cascade }
      t.references :security, type: :uuid, null: true, foreign_key: { on_delete: :nullify }
      t.references :price_raw_source_record, type: :uuid, null: true,
                   foreign_key: { to_table: :raw_source_records, on_delete: :nullify }
      t.string :theme, null: false
      t.string :ticker
      t.string :company_name, null: false
      t.string :action, null: false
      t.string :sleeve, null: false
      t.text :role_in_thesis, null: false
      t.text :valuation_context, null: false
      t.decimal :current_price, precision: 19, scale: 6
      t.string :price_currency, limit: 3
      t.datetime :price_as_of_at
      t.decimal :preferred_entry_low, precision: 19, scale: 6
      t.decimal :preferred_entry_high, precision: 19, scale: 6
      t.decimal :invalidation_price, precision: 19, scale: 6
      t.text :structural_thesis, null: false
      t.text :near_term_catalyst
      t.jsonb :principal_risks, null: false, default: []
      t.text :correlation_context, null: false
      t.string :portfolio_status, null: false, default: "unknown"
      t.decimal :current_weight_pct, precision: 8, scale: 4
      t.decimal :proposed_weight_pct, precision: 8, scale: 4
      t.text :competitive_position, null: false
      t.text :capital_intensity, null: false
      t.text :cash_generation_quality, null: false
      t.text :balance_sheet_quality, null: false
      t.decimal :confidence, precision: 5, scale: 4
      t.string :status, null: false, default: "draft"
      t.datetime :as_of_at, null: false
      t.jsonb :metadata, null: false, default: {}
      t.timestamps
    end

    add_index :investment_recommendations,
              [ :research_run_id, :theme, :action ],
              name: "idx_investment_recommendations_run_theme"

    create_table :investment_recommendation_claims, id: :uuid do |t|
      t.references :investment_recommendation, type: :uuid, null: false,
                   foreign_key: { on_delete: :cascade }
      t.references :research_claim, type: :uuid, null: false,
                   foreign_key: { on_delete: :cascade }
      t.string :role, null: false, default: "supports"
      t.timestamps
    end

    add_index :investment_recommendation_claims,
              [ :investment_recommendation_id, :research_claim_id ],
              unique: true,
              name: "idx_investment_recommendation_claims_unique"

    add_check_constraint :research_sources,
                         "source_tier BETWEEN 1 AND 4",
                         name: "chk_research_sources_tier"

    %i[authority evidence_quality independence methodological_transparency relevance recency].each do |column|
      add_check_constraint :research_sources,
                           "#{column} BETWEEN 0 AND 5",
                           name: "chk_research_sources_#{column}"
    end

    add_check_constraint :research_sources,
                         "overall_quality_score >= 0 AND overall_quality_score <= 5",
                         name: "chk_research_sources_overall_score"

    add_check_constraint :research_claims,
                         "confidence IS NULL OR (confidence >= 0 AND confidence <= 1)",
                         name: "chk_research_claims_confidence"

    add_check_constraint :research_evidences,
                         "weight >= 0 AND weight <= 1",
                         name: "chk_research_evidences_weight"

    add_check_constraint :investment_recommendations,
                         "confidence IS NULL OR (confidence >= 0 AND confidence <= 1)",
                         name: "chk_investment_recommendations_confidence"

    add_check_constraint :investment_recommendations,
                         "current_weight_pct IS NULL OR (current_weight_pct >= 0 AND current_weight_pct <= 100)",
                         name: "chk_investment_recommendations_current_weight"

    add_check_constraint :investment_recommendations,
                         "proposed_weight_pct IS NULL OR (proposed_weight_pct >= 0 AND proposed_weight_pct <= 100)",
                         name: "chk_investment_recommendations_proposed_weight"

    add_check_constraint :investment_recommendations,
                         "preferred_entry_low IS NULL OR preferred_entry_high IS NULL OR preferred_entry_low <= preferred_entry_high",
                         name: "chk_investment_recommendations_entry_zone"
  end
end

# frozen_string_literal: true

class CreatePhase4AccountingEngines < ActiveRecord::Migration[8.1]
  def change
    create_table :income_events, id: :uuid do |t|
      t.references :family, type: :uuid, null: false, foreign_key: { on_delete: :cascade }
      t.references :account, type: :uuid, null: true, foreign_key: { on_delete: :nullify }
      t.references :security, type: :uuid, null: true, foreign_key: { on_delete: :nullify }
      t.references :entry, type: :uuid, null: true, foreign_key: { on_delete: :nullify }
      t.references :raw_source_record, type: :uuid, null: true, foreign_key: { on_delete: :nullify }
      t.references :supersedes, type: :uuid, null: true, foreign_key: { to_table: :income_events, on_delete: :nullify }
      t.string :event_key, null: false, limit: 255
      t.string :income_type, null: false
      t.string :state, null: false
      t.decimal :gross_amount, precision: 19, scale: 4, null: false
      t.decimal :withholding_tax_amount, precision: 19, scale: 4, null: false, default: 0
      t.decimal :fee_amount, precision: 19, scale: 4, null: false, default: 0
      t.decimal :net_amount, precision: 19, scale: 4, null: false
      t.decimal :amount_per_unit, precision: 19, scale: 8
      t.decimal :units_entitled, precision: 34, scale: 18
      t.string :currency, null: false, limit: 3
      t.date :expected_date
      t.date :declaration_date
      t.date :accrual_start_date
      t.date :accrual_end_date
      t.date :payment_date
      t.datetime :received_at
      t.string :forecast_method
      t.decimal :confidence, precision: 5, scale: 4
      t.string :source_method
      t.jsonb :metadata, null: false, default: {}
      t.timestamps
    end

    add_index :income_events,
              [ :family_id, :event_key, :created_at ],
              name: "idx_income_events_event_versions"
    add_index :income_events,
              [ :family_id, :state, :currency ],
              name: "idx_income_events_state_currency"
    add_index :income_events,
              :supersedes_id,
              unique: true,
              where: "supersedes_id IS NOT NULL",
              name: "idx_income_events_single_successor"
    add_check_constraint :income_events,
                         "confidence IS NULL OR (confidence >= 0 AND confidence <= 1)",
                         name: "chk_income_events_confidence"
    add_check_constraint :income_events,
                         "gross_amount >= 0 AND withholding_tax_amount >= 0 AND fee_amount >= 0 AND net_amount >= 0",
                         name: "chk_income_events_nonnegative_amounts"

    create_table :liability_payments, id: :uuid do |t|
      t.references :family, type: :uuid, null: false, foreign_key: { on_delete: :cascade }
      t.references :account, type: :uuid, null: false, foreign_key: { on_delete: :cascade }
      t.references :entry, type: :uuid, null: true, foreign_key: { on_delete: :nullify }
      t.references :raw_source_record, type: :uuid, null: true, foreign_key: { on_delete: :nullify }
      t.string :kind, null: false
      t.date :payment_date, null: false
      t.integer :payment_number
      t.decimal :total_amount, precision: 19, scale: 4, null: false
      t.decimal :principal_amount, precision: 19, scale: 4, null: false, default: 0
      t.decimal :interest_amount, precision: 19, scale: 4, null: false, default: 0
      t.decimal :fee_amount, precision: 19, scale: 4, null: false, default: 0
      t.string :currency, null: false, limit: 3
      t.string :source_method
      t.string :dedupe_key, limit: 255
      t.jsonb :metadata, null: false, default: {}
      t.timestamps
    end

    add_index :liability_payments,
              [ :family_id, :dedupe_key ],
              unique: true,
              where: "dedupe_key IS NOT NULL",
              name: "idx_liability_payments_dedupe"
    add_index :liability_payments,
              [ :account_id, :payment_date, :kind ],
              name: "idx_liability_payments_account_date_kind"
    add_check_constraint :liability_payments,
                         "total_amount >= 0 AND principal_amount >= 0 AND interest_amount >= 0 AND fee_amount >= 0",
                         name: "chk_liability_payments_nonnegative"

    create_table :corporate_actions, id: :uuid do |t|
      t.references :family, type: :uuid, null: false, foreign_key: { on_delete: :cascade }
      t.references :security, type: :uuid, null: false, foreign_key: { on_delete: :cascade }
      t.references :successor_security, type: :uuid, null: true, foreign_key: { to_table: :securities, on_delete: :nullify }
      t.references :raw_source_record, type: :uuid, null: true, foreign_key: { on_delete: :nullify }
      t.references :supersedes, type: :uuid, null: true, foreign_key: { to_table: :corporate_actions, on_delete: :nullify }
      t.string :action_key, null: false, limit: 255
      t.string :action_type, null: false
      t.string :status, null: false, default: "announced"
      t.string :processing_mode, null: false, default: "manual_review"
      t.date :record_date
      t.date :effective_date, null: false
      t.date :payable_date
      t.decimal :ratio_numerator, precision: 34, scale: 18
      t.decimal :ratio_denominator, precision: 34, scale: 18
      t.decimal :cash_per_unit, precision: 19, scale: 8
      t.string :currency, limit: 3
      t.jsonb :terms, null: false, default: {}
      t.timestamps
    end

    add_index :corporate_actions,
              [ :family_id, :action_key, :created_at ],
              name: "idx_corporate_actions_versions"
    add_index :corporate_actions,
              [ :security_id, :effective_date ],
              name: "idx_corporate_actions_security_date"
    add_index :corporate_actions,
              :supersedes_id,
              unique: true,
              where: "supersedes_id IS NOT NULL",
              name: "idx_corporate_actions_single_successor"
    add_check_constraint :corporate_actions,
                         "ratio_numerator IS NULL OR ratio_numerator > 0",
                         name: "chk_corporate_actions_ratio_numerator"
    add_check_constraint :corporate_actions,
                         "ratio_denominator IS NULL OR ratio_denominator > 0",
                         name: "chk_corporate_actions_ratio_denominator"
  end
end

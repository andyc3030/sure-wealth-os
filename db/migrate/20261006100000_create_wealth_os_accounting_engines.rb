# frozen_string_literal: true

class CreateWealthOsAccountingEngines < ActiveRecord::Migration[8.1]
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
      t.decimal :amount, precision: 19, scale: 4
      t.decimal :cash_amount, precision: 19, scale: 4
      t.decimal :tax_withheld, precision: 19, scale: 4
      t.decimal :fees, precision: 19, scale: 4
      t.string :currency, null: false, limit: 3
      t.date :effective_date, null: false
      t.date :declared_on
      t.date :ex_date
      t.date :payable_on
      t.date :accrual_start
      t.date :accrual_end
      t.string :source_system
      t.string :method
      t.string :confidence, null: false, default: "unknown"
      t.jsonb :metadata, null: false, default: {}
      t.timestamps
    end

    add_index :income_events, [ :family_id, :event_key, :created_at ], name: "idx_income_events_lifecycle"
    add_index :income_events,
              [ :family_id, :event_key ],
              unique: true,
              where: "supersedes_id IS NULL",
              name: "idx_income_events_unique_root"
    add_index :income_events, [ :family_id, :state, :effective_date ], name: "idx_income_events_reporting"
    add_index :income_events, :supersedes_id, unique: true, where: "supersedes_id IS NOT NULL", name: "idx_income_events_one_successor"

    add_check_constraint :income_events, "amount IS NULL OR amount >= 0", name: "chk_income_events_amount_non_negative"
    add_check_constraint :income_events, "cash_amount IS NULL OR cash_amount >= 0", name: "chk_income_events_cash_non_negative"
    add_check_constraint :income_events, "tax_withheld IS NULL OR tax_withheld >= 0", name: "chk_income_events_tax_non_negative"
    add_check_constraint :income_events, "fees IS NULL OR fees >= 0", name: "chk_income_events_fees_non_negative"

    create_table :liability_payments, id: :uuid do |t|
      t.references :family, type: :uuid, null: false, foreign_key: { on_delete: :cascade }
      t.references :account, type: :uuid, null: false, foreign_key: { on_delete: :cascade }
      t.references :loan, type: :uuid, null: false, foreign_key: { on_delete: :cascade }
      t.references :entry, type: :uuid, null: true, foreign_key: { on_delete: :nullify }
      t.references :raw_source_record, type: :uuid, null: true, foreign_key: { on_delete: :nullify }

      t.date :payment_date, null: false
      t.string :state, null: false, default: "scheduled"
      t.decimal :total_amount, precision: 19, scale: 4, null: false
      t.decimal :principal_amount, precision: 19, scale: 4, null: false, default: 0
      t.decimal :interest_amount, precision: 19, scale: 4, null: false, default: 0
      t.decimal :fee_amount, precision: 19, scale: 4, null: false, default: 0
      t.decimal :insurance_amount, precision: 19, scale: 4, null: false, default: 0
      t.string :currency, null: false, limit: 3
      t.string :source_system
      t.integer :schedule_payment_number
      t.string :external_id
      t.jsonb :metadata, null: false, default: {}
      t.timestamps
    end

    add_index :liability_payments, [ :loan_id, :payment_date ], name: "idx_liability_payments_schedule"
    add_index :liability_payments,
              [ :loan_id, :payment_date, :source_system ],
              unique: true,
              where: "state = 'scheduled' AND source_system IS NOT NULL",
              name: "idx_liability_payments_unique_schedule"
    add_index :liability_payments,
              [ :family_id, :source_system, :external_id ],
              unique: true,
              where: "external_id IS NOT NULL AND source_system IS NOT NULL",
              name: "idx_liability_payments_source_identity"

    %w[total_amount principal_amount interest_amount fee_amount insurance_amount].each do |column|
      add_check_constraint :liability_payments, "#{column} >= 0", name: "chk_liability_payments_#{column}_non_negative"
    end

    create_table :corporate_actions, id: :uuid do |t|
      t.references :family, type: :uuid, null: false, foreign_key: { on_delete: :cascade }
      t.references :security, type: :uuid, null: false, foreign_key: { on_delete: :cascade }
      t.references :successor_security, type: :uuid, null: true, foreign_key: { to_table: :securities, on_delete: :nullify }
      t.references :raw_source_record, type: :uuid, null: true, foreign_key: { on_delete: :nullify }

      t.string :action_type, null: false
      t.string :status, null: false, default: "pending"
      t.date :effective_date, null: false
      t.decimal :ratio_numerator, precision: 34, scale: 18
      t.decimal :ratio_denominator, precision: 34, scale: 18
      t.decimal :cash_amount, precision: 19, scale: 4
      t.string :currency, limit: 3
      t.string :source_system
      t.string :external_id
      t.jsonb :metadata, null: false, default: {}
      t.timestamps
    end

    add_index :corporate_actions, [ :family_id, :security_id, :effective_date ], name: "idx_corporate_actions_position_math"
    add_index :corporate_actions,
              [ :family_id, :security_id, :action_type, :effective_date ],
              unique: true,
              where: "status = 'confirmed' AND action_type IN ('stock_split', 'reverse_split')",
              name: "idx_corporate_actions_unique_confirmed_split"
    add_index :corporate_actions,
              [ :family_id, :source_system, :external_id ],
              unique: true,
              where: "external_id IS NOT NULL AND source_system IS NOT NULL",
              name: "idx_corporate_actions_source_identity"

    add_check_constraint :corporate_actions,
                         "ratio_numerator IS NULL OR ratio_numerator > 0",
                         name: "chk_corporate_actions_ratio_num_positive"
    add_check_constraint :corporate_actions,
                         "ratio_denominator IS NULL OR ratio_denominator > 0",
                         name: "chk_corporate_actions_ratio_den_positive"
    add_check_constraint :corporate_actions,
                         "cash_amount IS NULL OR cash_amount >= 0",
                         name: "chk_corporate_actions_cash_non_negative"
  end
end

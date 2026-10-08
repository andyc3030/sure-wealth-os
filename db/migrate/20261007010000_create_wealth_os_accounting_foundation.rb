# frozen_string_literal: true

class CreateWealthOsAccountingFoundation < ActiveRecord::Migration[8.1]
  def change
    create_table :income_events, id: :uuid do |t|
      t.references :family, type: :uuid, null: false, foreign_key: { on_delete: :cascade }
      t.references :account, type: :uuid, null: true, foreign_key: { on_delete: :nullify }
      t.references :security, type: :uuid, null: true, foreign_key: { on_delete: :nullify }
      t.references :raw_source_record, type: :uuid, null: true, foreign_key: { on_delete: :nullify }
      t.string :canonical_key, null: false, limit: 255
      t.string :state, null: false
      t.string :income_type, null: false
      t.decimal :gross_amount, precision: 19, scale: 4, null: false, default: 0
      t.decimal :withholding_tax_amount, precision: 19, scale: 4, null: false, default: 0
      t.decimal :fee_amount, precision: 19, scale: 4, null: false, default: 0
      t.decimal :cash_received_amount, precision: 19, scale: 4
      t.string :currency, null: false, limit: 3
      t.date :expected_on
      t.date :accrual_start_date
      t.date :accrual_end_date
      t.date :declared_on
      t.date :payable_on
      t.date :received_on
      t.string :confidence, null: false, default: "unknown"
      t.string :source_system
      t.string :source_key, limit: 255
      t.jsonb :metadata, null: false, default: {}
      t.timestamps
    end

    add_index :income_events, [ :family_id, :canonical_key ],
              unique: true, name: "idx_income_events_family_canonical"
    add_index :income_events, [ :family_id, :state, :expected_on ],
              name: "idx_income_events_state_calendar"
    add_index :income_events, [ :family_id, :income_type, :state ],
              name: "idx_income_events_type_state"

    create_table :income_event_transitions, id: :uuid do |t|
      t.references :family, type: :uuid, null: false, foreign_key: { on_delete: :cascade }
      t.references :income_event, type: :uuid, null: false, foreign_key: { on_delete: :cascade }
      t.references :raw_source_record, type: :uuid, null: true, foreign_key: { on_delete: :nullify }
      t.string :from_state
      t.string :to_state, null: false
      t.datetime :occurred_at, null: false
      t.string :reason
      t.jsonb :snapshot, null: false, default: {}
      t.timestamps
    end

    add_index :income_event_transitions, [ :income_event_id, :occurred_at ],
              name: "idx_income_event_transitions_timeline"

    create_table :liability_payments, id: :uuid do |t|
      t.references :family, type: :uuid, null: false, foreign_key: { on_delete: :cascade }
      t.references :account, type: :uuid, null: false, foreign_key: { on_delete: :cascade }
      t.references :entry, type: :uuid, null: true, foreign_key: { on_delete: :nullify }
      t.references :raw_source_record, type: :uuid, null: true, foreign_key: { on_delete: :nullify }
      t.string :canonical_key, null: false, limit: 255
      t.date :payment_date, null: false
      t.string :payment_type, null: false
      t.decimal :total_amount, precision: 19, scale: 4, null: false
      t.decimal :principal_amount, precision: 19, scale: 4, null: false, default: 0
      t.decimal :interest_amount, precision: 19, scale: 4, null: false, default: 0
      t.decimal :fee_amount, precision: 19, scale: 4, null: false, default: 0
      t.decimal :insurance_amount, precision: 19, scale: 4, null: false, default: 0
      t.string :currency, null: false, limit: 3
      t.string :source_system
      t.string :source_key, limit: 255
      t.jsonb :metadata, null: false, default: {}
      t.timestamps
    end

    add_index :liability_payments, [ :family_id, :canonical_key ],
              unique: true, name: "idx_liability_payments_family_canonical"
    add_index :liability_payments, [ :account_id, :payment_date ],
              name: "idx_liability_payments_account_date"

    create_table :corporate_actions, id: :uuid do |t|
      t.references :family, type: :uuid, null: false, foreign_key: { on_delete: :cascade }
      t.references :account, type: :uuid, null: true, foreign_key: { on_delete: :nullify }
      t.references :security, type: :uuid, null: false, foreign_key: { on_delete: :cascade }
      t.references :successor_security, type: :uuid, null: true,
                   foreign_key: { to_table: :securities, on_delete: :nullify }
      t.references :raw_source_record, type: :uuid, null: true, foreign_key: { on_delete: :nullify }
      t.string :canonical_key, null: false, limit: 255
      t.string :action_type, null: false
      t.string :status, null: false, default: "observed"
      t.date :effective_date, null: false
      t.decimal :ratio_numerator, precision: 30, scale: 12
      t.decimal :ratio_denominator, precision: 30, scale: 12
      t.decimal :cash_amount, precision: 19, scale: 4
      t.string :currency, limit: 3
      t.string :source_system
      t.string :source_key, limit: 255
      t.jsonb :metadata, null: false, default: {}
      t.timestamps
    end

    add_index :corporate_actions, [ :family_id, :canonical_key ],
              unique: true, name: "idx_corporate_actions_family_canonical"
    add_index :corporate_actions, [ :security_id, :effective_date, :action_type ],
              name: "idx_corporate_actions_security_date"

    create_table :corporate_action_transitions, id: :uuid do |t|
      t.references :family, type: :uuid, null: false, foreign_key: { on_delete: :cascade }
      t.references :corporate_action, type: :uuid, null: false, foreign_key: { on_delete: :cascade }
      t.references :raw_source_record, type: :uuid, null: true, foreign_key: { on_delete: :nullify }
      t.string :from_status
      t.string :to_status, null: false
      t.datetime :occurred_at, null: false
      t.string :reason
      t.jsonb :snapshot, null: false, default: {}
      t.timestamps
    end

    add_index :corporate_action_transitions, [ :corporate_action_id, :occurred_at ],
              name: "idx_corporate_action_transitions_timeline"

    add_check_constraint :income_events,
                         "gross_amount >= 0 AND withholding_tax_amount >= 0 AND fee_amount >= 0 AND (cash_received_amount IS NULL OR cash_received_amount >= 0)",
                         name: "chk_income_events_nonnegative_amounts"
    add_check_constraint :income_events,
                         "state IN ('forecast', 'accrued', 'declared', 'received')",
                         name: "chk_income_events_state"
    add_check_constraint :income_events,
                         "income_type IN ('dividend', 'interest', 'coupon', 'distribution', 'rent', 'salary', 'pension', 'annuity', 'business_income', 'other')",
                         name: "chk_income_events_type"
    add_check_constraint :income_events,
                         "confidence IN ('confirmed', 'high', 'estimated', 'low', 'unknown')",
                         name: "chk_income_events_confidence"
    add_check_constraint :liability_payments,
                         "total_amount >= 0 AND principal_amount >= 0 AND interest_amount >= 0 AND fee_amount >= 0 AND insurance_amount >= 0",
                         name: "chk_liability_payments_nonnegative_amounts"
    add_check_constraint :liability_payments,
                         "payment_type IN ('actual', 'scheduled')",
                         name: "chk_liability_payments_type"
    add_check_constraint :liability_payments,
                         "total_amount = principal_amount + interest_amount + fee_amount + insurance_amount",
                         name: "chk_liability_payments_component_sum"
    add_check_constraint :corporate_actions,
                         "(ratio_numerator IS NULL OR ratio_numerator > 0) AND (ratio_denominator IS NULL OR ratio_denominator > 0)",
                         name: "chk_corporate_actions_positive_ratio"
    add_check_constraint :corporate_actions,
                         "action_type IN ('split', 'reverse_split', 'merger', 'spinoff', 'rights', 'ticker_change', 'cash_dividend', 'special_dividend', 'return_of_capital', 'fund_reorganization')",
                         name: "chk_corporate_actions_type"
    add_check_constraint :corporate_actions,
                         "status IN ('observed', 'validated', 'applied', 'reconciled', 'ignored')",
                         name: "chk_corporate_actions_status"
  end
end

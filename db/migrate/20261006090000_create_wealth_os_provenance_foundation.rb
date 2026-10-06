# frozen_string_literal: true

class CreateWealthOsProvenanceFoundation < ActiveRecord::Migration[8.1]
  def change
    create_table :raw_source_records, id: :uuid do |t|
      t.references :family, type: :uuid, null: false, foreign_key: { on_delete: :cascade }
      t.references :account, type: :uuid, null: true, foreign_key: { on_delete: :nullify }
      t.references :account_provider, type: :uuid, null: true, foreign_key: { on_delete: :nullify }
      t.string :source_system, null: false
      t.string :record_type, null: false
      t.string :source_key, null: false, limit: 255
      t.datetime :observed_at, null: false
      t.datetime :effective_at
      t.jsonb :payload, null: false, default: {}
      t.string :payload_sha256, null: false, limit: 64
      t.integer :schema_version, null: false, default: 1
      t.jsonb :metadata, null: false, default: {}
      t.timestamps
    end

    add_index :raw_source_records,
              [ :family_id, :source_system, :record_type, :source_key, :payload_sha256 ],
              unique: true,
              name: "idx_raw_source_records_content_identity"

    create_table :source_identities, id: :uuid do |t|
      t.references :family, type: :uuid, null: false, foreign_key: { on_delete: :cascade }
      t.references :raw_source_record, type: :uuid, null: true, foreign_key: { on_delete: :nullify }
      t.string :source_system, null: false
      t.string :entity_type, null: false
      t.string :external_id, null: false
      t.string :canonical_type, null: false
      t.uuid :canonical_id, null: false
      t.decimal :confidence, precision: 5, scale: 4, null: false, default: 1
      t.datetime :verified_at
      t.references :supersedes, type: :uuid, null: true, foreign_key: { to_table: :source_identities, on_delete: :nullify }
      t.timestamps
    end

    add_index :source_identities,
              [ :family_id, :source_system, :entity_type, :external_id, :created_at ],
              name: "idx_source_identities_lookup"
    add_index :source_identities,
              [ :canonical_type, :canonical_id ],
              name: "idx_source_identities_canonical"

    create_table :source_authority_rules, id: :uuid do |t|
      t.references :family, type: :uuid, null: false, foreign_key: { on_delete: :cascade }
      t.string :record_type, null: false
      t.string :field_name, null: false
      t.string :source_system, null: false
      t.integer :priority, null: false
      t.boolean :active, null: false, default: true
      t.text :notes
      t.timestamps
    end

    add_index :source_authority_rules,
              [ :family_id, :record_type, :field_name, :source_system ],
              unique: true,
              name: "idx_source_authority_rules_unique"

    create_table :source_conflicts, id: :uuid do |t|
      t.references :family, type: :uuid, null: false, foreign_key: { on_delete: :cascade }
      t.references :account, type: :uuid, null: true, foreign_key: { on_delete: :nullify }
      t.references :subject, polymorphic: true, type: :uuid, null: true, index: true
      t.string :field_name, null: false
      t.references :source_record_a, type: :uuid, null: false, foreign_key: { to_table: :raw_source_records }
      t.references :source_record_b, type: :uuid, null: false, foreign_key: { to_table: :raw_source_records }
      t.jsonb :value_a
      t.jsonb :value_b
      t.string :status, null: false, default: "open"
      t.string :resolution_rule
      t.references :selected_source_record, type: :uuid, null: true, foreign_key: { to_table: :raw_source_records, on_delete: :nullify }
      t.decimal :impact_amount, precision: 19, scale: 4
      t.string :currency, limit: 3
      t.datetime :detected_at, null: false
      t.datetime :resolved_at
      t.timestamps
    end

    add_index :source_conflicts,
              [ :family_id, :status, :field_name ],
              name: "idx_source_conflicts_open_work"
    add_index :source_conflicts,
              [ :source_record_a_id, :source_record_b_id, :field_name, :status ],
              name: "idx_source_conflicts_pair"

    create_table :reconciliation_events, id: :uuid do |t|
      t.references :family, type: :uuid, null: false, foreign_key: { on_delete: :cascade }
      t.references :account, type: :uuid, null: true, foreign_key: { on_delete: :nullify }
      t.references :account_provider, type: :uuid, null: true, foreign_key: { on_delete: :nullify }
      t.references :subject, polymorphic: true, type: :uuid, null: true, index: true
      t.references :raw_source_record, type: :uuid, null: true, foreign_key: { on_delete: :nullify }
      t.string :kind, null: false
      t.string :status, null: false
      t.jsonb :expected, null: false, default: {}
      t.jsonb :actual, null: false, default: {}
      t.jsonb :difference, null: false, default: {}
      t.boolean :material, null: false, default: false
      t.decimal :tolerance, precision: 19, scale: 8
      t.string :currency, limit: 3
      t.string :dedupe_key, limit: 255
      t.jsonb :details, null: false, default: {}
      t.datetime :occurred_at, null: false
      t.timestamps
    end

    add_index :reconciliation_events,
              [ :family_id, :dedupe_key ],
              unique: true,
              where: "dedupe_key IS NOT NULL",
              name: "idx_reconciliation_events_dedupe"
    add_index :reconciliation_events,
              [ :family_id, :status, :occurred_at ],
              name: "idx_reconciliation_events_status"

    add_reference :entries,
                  :raw_source_record,
                  type: :uuid,
                  null: true,
                  foreign_key: { on_delete: :nullify },
                  index: true

    add_reference :holdings,
                  :raw_source_record,
                  type: :uuid,
                  null: true,
                  foreign_key: { on_delete: :nullify },
                  index: true

    add_check_constraint :source_identities,
                         "confidence >= 0 AND confidence <= 1",
                         name: "chk_source_identities_confidence"

    add_check_constraint :source_authority_rules,
                         "priority >= 0",
                         name: "chk_source_authority_rules_priority"

    add_check_constraint :source_conflicts,
                         "source_record_a_id <> source_record_b_id",
                         name: "chk_source_conflicts_distinct_records"
  end
end

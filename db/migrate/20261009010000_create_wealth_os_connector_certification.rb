# frozen_string_literal: true

class CreateWealthOsConnectorCertification < ActiveRecord::Migration[8.1]
  def change
    create_table :connector_certifications, id: :uuid do |t|
      t.references :family, type: :uuid, null: false, foreign_key: { on_delete: :cascade }
      t.references :account, type: :uuid, null: true, foreign_key: { on_delete: :nullify }
      t.string :provider_key, null: false
      t.string :institution_key, null: false
      t.string :route_type, null: false
      t.string :environment, null: false
      t.string :status, null: false
      t.string :expected_scope, null: false
      t.string :observed_scope, null: false
      t.jsonb :checks, null: false, default: {}
      t.jsonb :evidence, null: false, default: {}
      t.string :evidence_sha256, null: false, limit: 64
      t.datetime :checked_at, null: false
      t.datetime :review_due_at
      t.uuid :reviewed_by_id
      t.references :supersedes,
                   type: :uuid,
                   null: true,
                   foreign_key: { to_table: :connector_certifications, on_delete: :nullify }
      t.text :notes
      t.timestamps
    end

    add_index :connector_certifications, :reviewed_by_id
    add_index :connector_certifications,
              [ :family_id, :provider_key, :institution_key, :checked_at ],
              name: "idx_connector_certifications_lookup"
    add_index :connector_certifications,
              :supersedes_id,
              unique: true,
              where: "supersedes_id IS NOT NULL",
              name: "idx_connector_certifications_one_successor"
    add_check_constraint :connector_certifications,
                         "environment IN ('sandbox', 'demo', 'production')",
                         name: "chk_connector_certifications_environment"
    add_check_constraint :connector_certifications,
                         "status IN ('passed', 'failed')",
                         name: "chk_connector_certifications_status"
    add_check_constraint :connector_certifications,
                         "evidence_sha256 ~ '^[0-9a-f]{64}$'",
                         name: "chk_connector_certifications_sha"

    create_table :ctrader_items, id: :uuid do |t|
      t.references :family, type: :uuid, null: false, foreign_key: { on_delete: :cascade }
      t.string :name, null: false, default: "cTrader"
      t.string :environment, null: false, default: "demo"
      t.string :status, null: false, default: "good"
      t.text :oauth_access_token
      t.text :oauth_refresh_token
      t.datetime :oauth_token_expires_at
      t.string :permission_scope
      t.jsonb :raw_accounts_payload, null: false, default: []
      t.datetime :last_synced_at
      t.boolean :scheduled_for_deletion, null: false, default: false
      t.timestamps
    end

    add_index :ctrader_items, [ :family_id, :environment ],
              name: "idx_ctrader_items_family_environment"
    add_check_constraint :ctrader_items,
                         "environment IN ('demo', 'live')",
                         name: "chk_ctrader_items_environment"
    add_check_constraint :ctrader_items,
                         "status IN ('good', 'requires_update')",
                         name: "chk_ctrader_items_status"

    create_table :ctrader_accounts, id: :uuid do |t|
      t.references :ctrader_item, type: :uuid, null: false, foreign_key: { on_delete: :cascade }
      t.bigint :ctid_trader_account_id, null: false
      t.bigint :trader_login
      t.boolean :is_live, null: false, default: false
      t.string :broker_name
      t.string :currency, limit: 3
      t.integer :money_digits
      t.decimal :balance, precision: 19, scale: 4
      t.decimal :equity, precision: 19, scale: 4
      t.decimal :used_margin, precision: 19, scale: 4
      t.decimal :free_margin, precision: 19, scale: 4
      t.jsonb :raw_payload, null: false, default: {}
      t.jsonb :raw_positions_payload, null: false, default: []
      t.jsonb :raw_orders_payload, null: false, default: []
      t.jsonb :raw_deals_payload, null: false, default: []
      t.jsonb :raw_cash_flows_payload, null: false, default: []
      t.datetime :last_synced_at
      t.timestamps
    end

    add_index :ctrader_accounts,
              [ :ctrader_item_id, :ctid_trader_account_id ],
              unique: true,
              name: "idx_ctrader_accounts_item_account"
  end
end

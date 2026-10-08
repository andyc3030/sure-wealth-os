# frozen_string_literal: true

class CreateWealthOsDailyCloseSnapshots < ActiveRecord::Migration[8.1]
  def change
    create_table :daily_close_snapshots, id: :uuid do |t|
      t.references :family, type: :uuid, null: false, foreign_key: { on_delete: :cascade }
      t.date :close_date, null: false
      t.datetime :cutoff_at, null: false
      t.datetime :closed_at, null: false
      t.string :timezone, null: false
      t.string :reporting_currency, null: false, limit: 3
      t.string :quality_status, null: false
      t.decimal :confidence, precision: 5, scale: 4, null: false
      t.decimal :gross_assets, precision: 19, scale: 4, null: false
      t.decimal :total_liabilities, precision: 19, scale: 4, null: false
      t.decimal :net_worth, precision: 19, scale: 4, null: false
      t.jsonb :payload, null: false, default: {}
      t.string :payload_sha256, null: false, limit: 64
      t.integer :schema_version, null: false, default: 1
      t.timestamps
    end

    add_index :daily_close_snapshots, [ :family_id, :close_date ],
              unique: true, name: "idx_daily_close_family_date"
    add_index :daily_close_snapshots, [ :family_id, :closed_at ],
              name: "idx_daily_close_family_closed_at"
    add_check_constraint :daily_close_snapshots,
                         "quality_status IN ('pass', 'warning')",
                         name: "chk_daily_close_quality_status"
    add_check_constraint :daily_close_snapshots,
                         "confidence >= 0 AND confidence <= 1",
                         name: "chk_daily_close_confidence"
    add_check_constraint :daily_close_snapshots,
                         "payload_sha256 ~ '^[0-9a-f]{64}$'",
                         name: "chk_daily_close_payload_sha256"
    add_check_constraint :daily_close_snapshots,
                         "schema_version > 0",
                         name: "chk_daily_close_schema_version"
  end
end

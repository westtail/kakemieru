class CreateSolidCacheEntries < ActiveRecord::Migration[8.0]
  # solid_cache（rate_limit 等で使用）のテーブルを primary DB に作成する。
  # 本番 database.yml の cache: は primary と同じ url を指すため、このテーブルがあれば
  # solid_cache_store がそのまま動作する（別 DB は不要）。定義は db/cache_schema.rb と同一。
  def change
    create_table :solid_cache_entries do |t|
      t.binary   :key,        limit: 1024,        null: false
      t.binary   :value,      limit: 536_870_912, null: false
      t.datetime :created_at,                     null: false
      t.integer  :key_hash,   limit: 8,           null: false
      t.integer  :byte_size,  limit: 4,           null: false
      t.index [ :byte_size ], name: "index_solid_cache_entries_on_byte_size"
      t.index [ :key_hash, :byte_size ], name: "index_solid_cache_entries_on_key_hash_and_byte_size"
      t.index [ :key_hash ], name: "index_solid_cache_entries_on_key_hash", unique: true
    end
  end
end

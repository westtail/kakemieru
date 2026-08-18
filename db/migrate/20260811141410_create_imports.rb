class CreateImports < ActiveRecord::Migration[8.0]
  # CSV 等の取り込み操作を1件にまとめる単位。1つの支払方法に複数の取り込みが紐づく。
  # user_id 単独インデックスは張らない（UNIQUE(user_id, file_hash) が user_id 先頭でカバー）。
  def change
    create_table :imports do |t|
      t.references :user, null: false, foreign_key: true, index: false
      t.references :payment_method, null: false, foreign_key: true
      t.string :source_type, null: false            # csv / ocr / api / manual_bulk（フェーズ1は csv）
      t.string :source_ref                          # csv はファイル名。manual_bulk 以外は必須（アプリ層）
      t.string :file_hash, null: false              # 重複取り込み防止（csv は内容の SHA256）
      t.integer :row_count, null: false, default: 0
      t.datetime :imported_at                       # 取り込み時刻（アップロード時に設定・S6）
      t.timestamps
    end

    # 同一ユーザーが同じ内容のファイルを二重取り込みするのを防ぐ。
    add_index :imports, [ :user_id, :file_hash ], unique: true

    add_check_constraint :imports,
                         "source_type IN ('csv','ocr','api','manual_bulk')",
                         name: "imports_source_type_check"
  end
end

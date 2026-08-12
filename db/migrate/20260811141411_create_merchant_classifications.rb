class CreateMerchantClassifications < ActiveRecord::Migration[8.0]
  # 店舗名 → カテゴリキーの全ユーザー共通マッピング（user_id を持たない）。
  # フェーズ1ではテーブルのみ作成し中身は空。分類ロジックは S6 以降。
  def change
    create_table :merchant_classifications do |t|
      t.string :merchant_name, null: false
      t.string :category_key, null: false           # categories.category_key と対応
      t.string :source, null: false                 # ai / user_manual
      t.datetime :classified_at
      t.timestamps

      t.index :merchant_name, unique: true
      t.index :category_key
    end

    add_check_constraint :merchant_classifications,
                         "source IN ('ai','user_manual')",
                         name: "merchant_classifications_source_check"
  end
end

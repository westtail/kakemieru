class CreateTransactions < ActiveRecord::Migration[8.1]
  def change
    create_table :transactions do |t|
      # user_id 単独インデックスは張らない（下の複合インデックスが user_id 先頭でカバー）。
      t.references :user, null: false, foreign_key: true, index: false
      t.references :payment_method, null: false, foreign_key: true, index: false
      # import_id は nullable（NULL = 手動入力）。import 削除は RESTRICT（既定）。index は default で作る。
      t.references :import, foreign_key: true
      # category_id は nullable（NULL = 未分類）。カテゴリ削除で NULL 化する。
      t.references :category, foreign_key: { on_delete: :nullify }, index: false

      t.date :date, null: false            # 原本（不変）
      t.integer :amount, null: false       # 原本・円（不変）
      t.string :description                 # CSV摘要原本。手動入力時は NULL
      t.string :merchant_name, null: false # 正規化店舗名（編集可・分類キー）
      t.integer :amount_override           # 訂正値（NULL = 原本を使用）
      t.date :date_override                # 訂正値（NULL = 原本を使用）

      # 集計・グラフ・月絞り込みは必ず effective_* を使う（PostgreSQL の STORED 生成カラム）。
      t.virtual :effective_amount, type: :integer, as: "COALESCE(amount_override, amount)", stored: true
      t.virtual :effective_date, type: :date, as: "COALESCE(date_override, date)", stored: true

      t.datetime :deleted_at               # ソフトデリート（NULL = 有効）
      t.timestamps
    end

    # deleted_at を2列目に置き `WHERE user_id=? AND deleted_at IS NULL` をインデックスで処理する。
    add_index :transactions, [ :user_id, :deleted_at, :effective_date ],
              name: "index_transactions_on_user_active_effective_date"
    add_index :transactions, [ :user_id, :deleted_at, :category_id, :effective_date ],
              name: "index_transactions_on_user_active_category"
    add_index :transactions, [ :user_id, :deleted_at, :payment_method_id ],
              name: "index_transactions_on_user_active_payment_method"
    add_index :transactions, [ :user_id, :merchant_name ],
              name: "index_transactions_on_user_merchant_name"
  end
end

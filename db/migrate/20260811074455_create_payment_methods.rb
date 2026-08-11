class CreatePaymentMethods < ActiveRecord::Migration[8.0]
  def change
    # ユーザーごとの支払方法。登録時に payment_type:cash の「現金」が1件自動生成される。
    # user_id 単独インデックスは張らない（下の複合インデックスが user_id 先頭でカバーするため）。
    create_table :payment_methods do |t|
      t.references :user, null: false, foreign_key: true, index: false
      t.string :name, null: false
      t.string :payment_type, null: false
      t.datetime :archived_at            # NULL = 使用中 / 値あり = アーカイブ（アーカイブ運用は S7）
      t.timestamps
    end

    # 同一ユーザー内で名前重複を禁止。
    add_index :payment_methods, [ :user_id, :name ], unique: true
    # S7 の transactions 複合FK (user_id, payment_method_id) → payment_methods(user_id, id) の参照先。
    add_index :payment_methods, [ :user_id, :id ], unique: true
    # アクティブ絞り込み（WHERE archived_at IS NULL 相当）用。
    add_index :payment_methods, [ :user_id, :archived_at ]

    # payment_type を 5 値に限定（Rails enum と二重で守る）。値は履歴を不変にするためインライン。
    add_check_constraint :payment_methods,
                         "payment_type IN ('credit','debit','e_money','qr','cash')",
                         name: "payment_methods_payment_type_check"
  end
end

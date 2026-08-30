# 特別ルール（同名店舗を金額範囲・毎月の日で判別する分類・ADR-0048）。
# テナント整合は複合FK (user_id, category_id)→categories(user_id, id) で DB 層でも担保する
# （#113 と同型）。同一店舗に複数ルール（OR 表現）を許すため merchant_name は一意にしない。
class CreateSpecialRules < ActiveRecord::Migration[8.1]
  def up
    create_table :special_rules do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      t.string :merchant_name, null: false
      t.integer :amount_min
      t.integer :amount_max
      t.integer :day_of_month
      t.bigint :category_id, null: false
      t.string :note
      t.timestamps
    end

    add_index :special_rules, [ :user_id, :merchant_name ]

    execute <<~SQL
      ALTER TABLE special_rules
        ADD CONSTRAINT fk_special_rules_user_category
        FOREIGN KEY (user_id, category_id)
        REFERENCES categories (user_id, id)
        ON DELETE CASCADE
    SQL
  end

  def down
    drop_table :special_rules
  end
end

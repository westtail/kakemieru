# merchant_classifications を「全ユーザー共通の merchant_name→category_key」から
# 「ユーザー個別の merchant_name→category_id」へ作り替える（#152）。テーブルは空のため
# データ移行は不要。テナント整合は複合FK (user_id, category_id)→categories(user_id, id) で
# DB 層でも担保する（#113 と同型）。
class RedesignMerchantClassificationsPerUser < ActiveRecord::Migration[8.1]
  def up
    remove_index :merchant_classifications, :merchant_name
    remove_index :merchant_classifications, :category_key
    remove_column :merchant_classifications, :category_key

    add_column :merchant_classifications, :user_id, :bigint, null: false
    add_column :merchant_classifications, :category_id, :bigint, null: false
    add_index :merchant_classifications, [ :user_id, :merchant_name ], unique: true

    add_foreign_key :merchant_classifications, :users, on_delete: :cascade
    execute <<~SQL
      ALTER TABLE merchant_classifications
        ADD CONSTRAINT fk_merchant_classifications_user_category
        FOREIGN KEY (user_id, category_id)
        REFERENCES categories (user_id, id)
        ON DELETE CASCADE
    SQL
  end

  def down
    execute "ALTER TABLE merchant_classifications DROP CONSTRAINT fk_merchant_classifications_user_category"
    remove_foreign_key :merchant_classifications, :users
    remove_index :merchant_classifications, [ :user_id, :merchant_name ]
    remove_column :merchant_classifications, :user_id
    remove_column :merchant_classifications, :category_id

    add_column :merchant_classifications, :category_key, :string, null: false
    add_index :merchant_classifications, :category_key
    add_index :merchant_classifications, :merchant_name, unique: true
  end
end

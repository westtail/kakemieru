class CreateCategoryTables < ActiveRecord::Migration[8.0]
  def change
    # システム共通のカテゴリテンプレート（不変・ユーザー編集不可）。
    create_table :category_templates do |t|
      t.string :category_key, null: false
      t.string :name, null: false
      t.timestamps
      t.index :category_key, unique: true
    end

    # ユーザーごとのカテゴリ。登録時に category_templates からコピーされる。
    # user_id 単独インデックスは張らない（下の複合インデックスが user_id 先頭でカバーするため）。
    create_table :categories do |t|
      t.references :user, null: false, foreign_key: true, index: false
      t.string :category_key            # 初期カテゴリはキーあり / 独自カテゴリは NULL
      t.string :name, null: false
      t.timestamps
    end

    # 同一ユーザー内で名前重複を禁止。
    add_index :categories, [ :user_id, :name ], unique: true
    # 初期カテゴリ（キーあり）の重複コピーを防ぐ部分ユニークインデックス。
    add_index :categories, [ :user_id, :category_key ], unique: true,
              where: "category_key IS NOT NULL",
              name: "index_categories_on_user_id_and_category_key"
    # S7 の transactions 複合FK (user_id, category_id) → categories(user_id, id) の参照先。
    # Rails は主キーのみ参照するため複合ユニークを別途張る。
    add_index :categories, [ :user_id, :id ], unique: true
  end
end

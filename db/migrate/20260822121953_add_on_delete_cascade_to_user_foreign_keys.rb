# users を参照する全外部キーに DB レベルの ON DELETE CASCADE を張る（#110）。
# DATABASE_DESIGN の「users 削除 → CASCADE」を DB 層で担保し、ActiveRecord を
# 経由しない削除（生 SQL・delete_all 等）でも退会カスケードが一貫するようにする。
#
# 単一 DDL トランザクション（Rails 既定）で remove → add を原子的に行う。他セッションからは
# 旧 FK か新 FK のどちらかしか見えず、「FK が一瞬消える隙間」が生じない（＝その隙間での
# DELETE による孤児化が起きない）。対象テーブルは小規模のため検証スキャンのロックも短時間。
# 将来テーブルが肥大化して単一トランザクションのロックが問題になる場合は、一時名の cascade FK
# を先に足して検証後に旧 FK を落とすオンライン方式へ切り替える。
class AddOnDeleteCascadeToUserForeignKeys < ActiveRecord::Migration[8.1]
  # users を直接参照するテーブル（transactions も user FK を持つため含める）。
  TABLES = %i[categories imports payment_methods sessions transactions].freeze

  def up
    TABLES.each do |table|
      remove_foreign_key table, :users
      add_foreign_key table, :users, on_delete: :cascade
    end
  end

  def down
    TABLES.each do |table|
      remove_foreign_key table, :users
      # 変更前は on_delete 指定なし（NO ACTION）だったため、無指定で張り直して復元する。
      add_foreign_key table, :users
    end
  end
end

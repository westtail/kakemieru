# users を参照する全外部キーに DB レベルの ON DELETE CASCADE を張る（#110）。
# DATABASE_DESIGN の「users 削除 → CASCADE」を DB 層で担保し、ActiveRecord を
# 経由しない削除（生 SQL・delete_all 等）でも退会カスケードが一貫するようにする。
#
# 本番のロックを最小化するため、単一トランザクションで全テーブルを同時ロックせず、
# NOT VALID で瞬時に張ってから validate で検証する（validate は弱いロックで
# 書き込みを止めない）。そのため DDL トランザクションを無効化する。
class AddOnDeleteCascadeToUserForeignKeys < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  # users を直接参照するテーブル（transactions も user FK を持つため含める）。
  TABLES = %i[categories imports payment_methods sessions transactions].freeze

  def up
    TABLES.each do |table|
      remove_foreign_key table, :users
      add_foreign_key table, :users, on_delete: :cascade, validate: false
      validate_foreign_key table, :users
    end
  end

  def down
    TABLES.each do |table|
      remove_foreign_key table, :users
      # 変更前は on_delete 指定なし（NO ACTION）だったため、無指定で張り直して復元する。
      add_foreign_key table, :users, validate: false
      validate_foreign_key table, :users
    end
  end
end

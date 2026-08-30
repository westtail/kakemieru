# 取込時の自動適用トグルを種類別に分ける（ADR-0048）。既存の単一 bool を店舗ルール用に
# リネームし、特別ルール用を追加する（初期 false）。
class SplitImportAutoApplySettings < ActiveRecord::Migration[8.1]
  def change
    rename_column :users, :auto_apply_rules_on_import, :auto_apply_merchant_rules_on_import
    add_column :users, :auto_apply_special_rules_on_import, :boolean, null: false, default: false
  end
end

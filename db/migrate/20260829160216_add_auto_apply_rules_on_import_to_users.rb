# 取込時に店舗ルールを未分類明細へ自動適用するか（アカウント設定・ADR-0047）。
# 初期値は false（明示的にオンにするまで自動では当てない）。
class AddAutoApplyRulesOnImportToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :auto_apply_rules_on_import, :boolean, null: false, default: false
  end
end

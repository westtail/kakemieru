# 店舗ルール（明示登録）へ再設計（ADR-0047）。全ルールがユーザーの明示登録になり、
# 学習メタ情報（source / classified_at）が不要になったため削除する。テーブルは空のため
# データ移行は不要。source の CHECK 制約は列削除に伴い自動で消える。
class SimplifyMerchantClassifications < ActiveRecord::Migration[8.1]
  def up
    remove_column :merchant_classifications, :source
    remove_column :merchant_classifications, :classified_at
  end

  def down
    add_column :merchant_classifications, :classified_at, :datetime
    add_column :merchant_classifications, :source, :string, null: false, default: "user_manual"
    change_column_default :merchant_classifications, :source, nil
    add_check_constraint :merchant_classifications,
      "source::text = ANY (ARRAY['ai'::character varying, 'user_manual'::character varying]::text[])",
      name: "merchant_classifications_source_check"
  end
end

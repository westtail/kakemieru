# 特別ルールのドメイン制約を DB 層でも固める（ADR-0048・レビュー L3）。モデル検証に加え、
# update_all/生SQL/コンソール直挿入でも day_of_month の範囲と金額範囲の順序を担保する。
class AddSpecialRuleCheckConstraints < ActiveRecord::Migration[8.1]
  def change
    add_check_constraint :special_rules,
      "day_of_month IS NULL OR (day_of_month BETWEEN 1 AND 31)",
      name: "special_rules_day_of_month_range"
    add_check_constraint :special_rules,
      "amount_min IS NULL OR amount_max IS NULL OR amount_min <= amount_max",
      name: "special_rules_amount_range_order"
  end
end

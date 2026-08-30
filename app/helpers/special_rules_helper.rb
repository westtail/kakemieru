module SpecialRulesHelper
  # 特別ルールの条件（金額範囲・毎月の日）を人が読める文字列にする。
  def special_rule_condition_label(rule)
    [ amount_condition_label(rule), day_condition_label(rule) ].compact.join("・").presence || "条件なし"
  end

  private
    def amount_condition_label(rule)
      min = rule.amount_min
      max = rule.amount_max
      if min && max
        min == max ? "金額 #{yen(min)}" : "金額 #{yen(min)}〜#{yen(max)}"
      elsif min
        "金額 #{yen(min)} 以上"
      elsif max
        "金額 #{yen(max)} 以下"
      end
    end

    def day_condition_label(rule)
      "毎月#{rule.day_of_month}日" if rule.day_of_month
    end

    def yen(amount)
      "¥#{number_with_delimiter(amount)}"
    end
end

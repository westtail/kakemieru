# 明細を店舗ルール（ADR-0047）と特別ルール（ADR-0048）で分類する統一マッチャ。
# 優先順位は「特別ルール（具体的）→ 店舗ルール（名前のみ）→ 未分類（nil）」。
# 取込設定の2トグルに応じて use_merchant/use_special を切り替える（更新実行は両方 true）。
# ルール群は初期化時に一括ロードし、明細ループ内での N+1 を避ける。照合キーは
# CategoryClassifier.normalize で正規化する。
class RuleMatcher
  Match = Struct.new(:category_id, :note, keyword_init: true)

  def initialize(user:, use_merchant: true, use_special: true)
    @user = user
    @use_merchant = use_merchant
    @use_special = use_special
    load_rules
  end

  # 明細1件（店舗名・実効金額・実効日）を解決する。一致すれば Match、無ければ nil。
  def match(merchant_name:, amount:, date:)
    key = CategoryClassifier.normalize(merchant_name)
    return nil if key.blank?

    if @use_special && (rule = best_special(key, amount, date))
      return Match.new(category_id: rule.category_id, note: rule.note)
    end

    if @use_merchant && (category_id = @merchant_rules[key])
      return Match.new(category_id: category_id, note: nil)
    end

    nil
  end

  private
    def load_rules
      @merchant_rules =
        @use_merchant ? @user.merchant_classifications.pluck(:merchant_name, :category_id).to_h : {}
      # 特別ルールは正規化済み merchant_name でグルーピング（1店舗に複数ルール＝OR）。
      @special_rules = @use_special ? @user.special_rules.to_a.group_by(&:merchant_name) : {}
    end

    # 一致する特別ルールのうち最も具体的なものを選ぶ（条件数多い→金額幅狭い→id 昇順）。
    def best_special(key, amount, date)
      candidates = (@special_rules[key] || []).select { |rule| rule.matches?(amount: amount, day: date.day) }
      return nil if candidates.empty?

      candidates.min_by { |rule| [ -rule.specificity, rule.amount_span, rule.id || 0 ] }
    end
end

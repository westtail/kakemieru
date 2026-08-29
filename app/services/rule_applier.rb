# 店舗ルールを未分類の明細へ一括適用する（ADR-0047）。取込時の自動適用（設定ON時）と
# 「更新実行」ボタンの両方から呼ぶ。対象は本人の未削除・未分類（category_id NULL）明細のみで、
# 手動で付けたカテゴリは上書きしない。更新した件数を返す。
class RuleApplier
  def initialize(user:)
    @user = user
  end

  def call
    rules = @user.merchant_classifications.pluck(:merchant_name, :category_id).to_h # 正規化済みキー
    return 0 if rules.empty?

    # 未分類明細を1クエリで読み、店舗名を正規化してルールに当てる。カテゴリ別に id をまとめ、
    # まとめて update_all（行ごとの update を避ける）。テナント整合は user スコープ＋複合FKで担保。
    ids_by_category = Hash.new { |hash, key| hash[key] = [] }
    @user.transactions.not_deleted.where(category_id: nil)
         .pluck(:id, :merchant_name).each do |id, merchant_name|
      category_id = rules[CategoryClassifier.normalize(merchant_name)]
      ids_by_category[category_id] << id if category_id
    end

    now = Time.current
    ids_by_category.sum do |category_id, ids|
      @user.transactions.where(id: ids).update_all(category_id: category_id, updated_at: now)
    end
  end
end

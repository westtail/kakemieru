# 店舗名からユーザーの店舗ルール（merchant_classifications）を引き、紐づく category_id を返す。
# 一致しなければ nil（= 未分類）。店舗ルールはおすすめからの明示登録で蓄積され（ADR-0047）、
# 取込時の自動適用（設定ON時）や「更新実行」での未分類への一括適用に使われる。
class CategoryClassifier
  def self.category_id_for(user, merchant_name)
    category_ids_for(user, [ merchant_name ])[normalize(merchant_name)]
  end

  # 複数の店舗名をまとめて解決する（取り込みの一括保存で行ごとの N+1 を避ける）。
  # 戻り値: { 正規化済み店舗名 => category_id }（該当なしの店舗はキーごと含めない）。
  def self.category_ids_for(user, merchant_names)
    names = merchant_names.filter_map { |name| normalize(name).presence }.uniq
    return {} if names.empty?

    user.merchant_classifications.where(merchant_name: names).pluck(:merchant_name, :category_id).to_h
  end

  # 照合キーの正規化: NFKC（全角→半角）+ 前後空白除去 + 小文字化。
  # "Amazon" と "amazon"、全角/半角/空白違いを同一キーに揃える。
  # MerchantClassification も同じ正規化で保存する（normalizes）。
  def self.normalize(merchant_name)
    merchant_name.to_s.unicode_normalize(:nfkc).strip.downcase
  end
end

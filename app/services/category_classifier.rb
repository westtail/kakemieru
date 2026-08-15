# 店舗名から全ユーザー共通の merchant_classifications を引き、ユーザーの同 category_key の
# カテゴリ id を返す。一致しなければ nil（= 未分類）。
# フェーズ1では merchant_classifications が空なので実質すべて nil（将来埋まれば自動で効く）。
class CategoryClassifier
  def self.category_id_for(user, merchant_name)
    category_ids_for(user, [ merchant_name ])[normalize(merchant_name)]
  end

  # 複数の店舗名をまとめて解決する（取り込みの一括保存で行ごとの N+1 を避ける）。
  # 戻り値: { 正規化済み店舗名 => category_id or nil }
  def self.category_ids_for(user, merchant_names)
    names = merchant_names.filter_map { |name| normalize(name).presence }.uniq
    return {} if names.empty?

    key_by_name = MerchantClassification.where(merchant_name: names).pluck(:merchant_name, :category_key).to_h
    return {} if key_by_name.empty?

    id_by_key = user.categories.where(category_key: key_by_name.values.uniq).pluck(:category_key, :id).to_h
    key_by_name.transform_values { |category_key| id_by_key[category_key] }
  end

  # 照合キーの正規化: NFKC（全角→半角）+ 前後空白除去 + 小文字化。
  # "Amazon" と "amazon"、全角/半角/空白違いを同一キーに揃える。
  # MerchantClassification も同じ正規化で保存する（normalizes）。
  def self.normalize(merchant_name)
    merchant_name.to_s.unicode_normalize(:nfkc).strip.downcase
  end
end

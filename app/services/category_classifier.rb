# 店舗名の照合キーを正規化する共有ユーティリティ。店舗ルール（MerchantClassification）・
# 特別ルール（SpecialRule）の保存、RuleMatcher の照合、MerchantRecommendations の集計が
# この正規化を共有し、"Amazon" と "amazon"、全角/半角/前後空白違いを同一キーに揃える。
class CategoryClassifier
  # 照合キーの正規化: NFKC（全角→半角）+ 前後空白除去 + 小文字化。
  def self.normalize(merchant_name)
    merchant_name.to_s.unicode_normalize(:nfkc).strip.downcase
  end
end

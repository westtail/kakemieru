# 店舗ルール（ユーザーが明示登録する 店舗名 → カテゴリ の確定マッピング）。
# おすすめ（履歴集計）から登録される、または手動追加される。取込時／更新実行で未分類明細へ
# 適用する読み取りは CategoryClassifier。merchant_name は CategoryClassifier.normalize で
# 正規化して保存・照合する（"Amazon"/"amazon"、全角/半角/空白違いを同一キーに揃える）。
# == Schema Information
#
# Table name: merchant_classifications
#
#  id            :bigint           not null, primary key
#  merchant_name :string           not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  category_id   :bigint           not null
#  user_id       :bigint           not null
#
# Indexes
#
#  index_merchant_classifications_on_user_id_and_merchant_name  (user_id,merchant_name) UNIQUE
#
# Foreign Keys
#
#  fk_merchant_classifications_user_category  ([user_id, category_id] => categories[user_id, id]) ON DELETE => cascade
#  fk_rails_...                               (user_id => users.id) ON DELETE => cascade
#
class MerchantClassification < ApplicationRecord
  belongs_to :user
  belongs_to :category

  normalizes :merchant_name, with: ->(value) { CategoryClassifier.normalize(value) }

  validates :merchant_name, presence: true, length: { maximum: 255 }, uniqueness: { scope: :user_id }
  # 他ユーザーの category を紐づけない（複合FKと二層。Transaction のテナント整合に倣う）。
  validate :category_belongs_to_user

  private
    def category_belongs_to_user
      return if category.nil? || user.nil?

      errors.add(:category, :invalid) if category.user_id != user_id
    end
end

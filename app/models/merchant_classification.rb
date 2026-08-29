# 店舗名 → カテゴリのマッピング（ユーザー個別・#152）。手動でカテゴリを付けたときに
# source=user_manual で記録し、次回同じ店舗の CSV 取込を自動分類する（読み取りは
# CategoryClassifier）。merchant_name は CategoryClassifier.normalize で正規化して保存・照合。
# == Schema Information
#
# Table name: merchant_classifications
#
#  id            :bigint           not null, primary key
#  classified_at :datetime
#  merchant_name :string           not null
#  source        :string           not null
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
  SOURCES = %w[ai user_manual].freeze

  belongs_to :user
  belongs_to :category

  normalizes :merchant_name, with: ->(value) { CategoryClassifier.normalize(value) }

  validates :merchant_name, presence: true, uniqueness: { scope: :user_id }
  validates :source, presence: true, inclusion: { in: SOURCES }
  # 他ユーザーの category を紐づけない（複合FKと二層。Transaction のテナント整合に倣う）。
  validate :category_belongs_to_user

  # 手動分類の学習: 正規化店舗名 → category_id を user_manual で upsert する。
  # 空店舗名は無視。既存があれば上書きして最新の手動分類を優先する。
  def self.learn(user:, merchant_name:, category_id:)
    name = CategoryClassifier.normalize(merchant_name)
    return if name.blank? || category_id.blank?

    record = user.merchant_classifications.find_or_initialize_by(merchant_name: name)
    record.update!(category_id: category_id, source: "user_manual", classified_at: Time.current)
  end

  # 未分類化したときにその店舗のマッピングを削除する（以後は自動分類しない）。
  def self.forget(user:, merchant_name:)
    name = CategoryClassifier.normalize(merchant_name)
    return if name.blank?

    user.merchant_classifications.where(merchant_name: name).delete_all
  end

  private
    def category_belongs_to_user
      return if category.nil? || user.nil?

      errors.add(:category, :invalid) if category.user_id != user_id
    end
end

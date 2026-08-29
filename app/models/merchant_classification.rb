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

  # 手動分類の学習: 複数店舗をまとめて user_manual で upsert する（一括適用の N+1 回避）。
  # 店舗名は正規化＆重複除去。既存があれば上書きして最新の手動分類を優先する。
  # upsert なので同店舗の並行学習でも RecordNotUnique にならない（原子的）。テナント整合は
  # 呼び出し側のカテゴリ所有チェック＋複合FKで担保（upsert はモデル検証を通らない）。
  # 未分類（category_id 空）や該当店舗なしのときは何もしない（未分類化での忘却はしない）。
  def self.learn_all(user:, merchant_names:, category_id:)
    return if category_id.blank?

    now = Time.current
    rows = Array(merchant_names)
             .filter_map { |name| CategoryClassifier.normalize(name).presence }.uniq
             .map do |name|
               { user_id: user.id, merchant_name: name, category_id: category_id,
                 source: "user_manual", classified_at: now, created_at: now, updated_at: now }
             end
    return if rows.empty?

    upsert_all(rows, unique_by: %i[user_id merchant_name])
  end

  private
    def category_belongs_to_user
      return if category.nil? || user.nil?

      errors.add(:category, :invalid) if category.user_id != user_id
    end
end

# 店舗名 → カテゴリキーの全ユーザー共通マッピング（user_id を持たない）。
# フェーズ1ではテーブルのみで中身は空（自動投入は S6 以降）。category_key は
# categories.category_key と対応し、ユーザーごとの category に解決する。
# == Schema Information
#
# Table name: merchant_classifications
#
#  id            :bigint           not null, primary key
#  category_key  :string           not null
#  classified_at :datetime
#  merchant_name :string           not null
#  source        :string           not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#
# Indexes
#
#  index_merchant_classifications_on_category_key   (category_key)
#  index_merchant_classifications_on_merchant_name  (merchant_name) UNIQUE
#
class MerchantClassification < ApplicationRecord
  SOURCES = %w[ai user_manual].freeze

  # CategoryClassifier と同じ正規化で保存・照合する（大文字小文字/全角/空白違いを吸収）。
  normalizes :merchant_name, with: ->(value) { CategoryClassifier.normalize(value) }

  validates :merchant_name, presence: true, uniqueness: true
  validates :category_key, presence: true
  validates :source, presence: true, inclusion: { in: SOURCES }
end

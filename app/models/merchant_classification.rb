# 店舗名 → カテゴリキーの全ユーザー共通マッピング（user_id を持たない）。
# フェーズ1ではテーブルのみで中身は空（自動投入は S6 以降）。category_key は
# categories.category_key と対応し、ユーザーごとの category に解決する。
class MerchantClassification < ApplicationRecord
  SOURCES = %w[ai user_manual].freeze

  validates :merchant_name, presence: true, uniqueness: true
  validates :category_key, presence: true
  validates :source, presence: true, inclusion: { in: SOURCES }
end

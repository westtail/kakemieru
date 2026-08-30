# 特別ルール（同名店舗を金額範囲・毎月の日で判別する分類・ADR-0048）。店舗ルール
# （MerchantClassification）より具体的な条件を持ち、照合では優先される（RuleMatcher）。
# merchant_name は CategoryClassifier.normalize で正規化して保存・照合する。条件（金額範囲・
# 毎月の日）はすべて AND。OR は同一カテゴリへ複数ルールを作って表現する。
# == Schema Information
#
# Table name: special_rules
#
#  id            :bigint           not null, primary key
#  amount_max    :integer
#  amount_min    :integer
#  day_of_month  :integer
#  merchant_name :string           not null
#  note          :string
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  category_id   :bigint           not null
#  user_id       :bigint           not null
#
# Indexes
#
#  index_special_rules_on_user_id                    (user_id)
#  index_special_rules_on_user_id_and_merchant_name  (user_id,merchant_name)
#
# Foreign Keys
#
#  fk_rails_...                    (user_id => users.id) ON DELETE => cascade
#  fk_special_rules_user_category  ([user_id, category_id] => categories[user_id, id]) ON DELETE => cascade
#
class SpecialRule < ApplicationRecord
  belongs_to :user
  belongs_to :category

  normalizes :merchant_name, with: ->(value) { CategoryClassifier.normalize(value) }

  validates :merchant_name, presence: true, length: { maximum: 255 }
  validates :note, length: { maximum: 255 }, allow_nil: true
  validates :amount_min, :amount_max,
            numericality: { only_integer: true, greater_than_or_equal_to: -2_147_483_648,
                            less_than_or_equal_to: 2_147_483_647 }, allow_nil: true
  validates :day_of_month,
            numericality: { only_integer: true, greater_than_or_equal_to: 1, less_than_or_equal_to: 31 },
            allow_nil: true
  # 他ユーザーの category を紐づけない（複合FKと二層。MerchantClassification に倣う）。
  validate :category_belongs_to_user
  validate :amount_range_order
  validate :at_least_one_condition

  # 明細（金額・日）がこのルールの条件（設定分のみ）を満たすか。未設定の条件は評価しない。
  def matches?(amount:, day:)
    return false if amount_min && amount < amount_min
    return false if amount_max && amount > amount_max
    return false if day_of_month && day != day_of_month

    true
  end

  # 具体度（設定された条件の数）。複数一致時、大きいほど優先する。
  def specificity
    [ amount_min, amount_max, day_of_month ].count { |value| !value.nil? }
  end

  # 金額幅（狭いほど具体的）。両端のどちらかが未設定なら無限大扱い。
  def amount_span
    return Float::INFINITY if amount_min.nil? || amount_max.nil?

    amount_max - amount_min
  end

  private
    def category_belongs_to_user
      return if category.nil? || user.nil?

      errors.add(:category, :invalid) if category.user_id != user_id
    end

    def amount_range_order
      return if amount_min.nil? || amount_max.nil?

      errors.add(:amount_max, :invalid) if amount_max < amount_min
    end

    def at_least_one_condition
      return if amount_min.present? || amount_max.present? || day_of_month.present?

      errors.add(:base, "金額または毎月の日のいずれかの条件を指定してください。")
    end
end

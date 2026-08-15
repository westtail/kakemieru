# 明細（取り込み・手動入力の1件）。
# - date/amount は原本（不変）。訂正は amount_override/date_override に入れる。
# - effective_amount/effective_date は DB の STORED 生成カラム（COALESCE(override, 原本)）で、
#   集計・グラフ・月絞り込みは必ずこちらを使う。Rails からは書き込まない（読み取り専用）。
# - import_id = NULL は手動入力、category_id = NULL は未分類。
# - 取り消しは物理削除せず deleted_at（ソフトデリート）で行う。
class Transaction < ApplicationRecord
  belongs_to :user
  belongs_to :payment_method
  belongs_to :import, optional: true
  belongs_to :category, optional: true

  # user_id / payment_method_id の必須は belongs_to（既定で必須）が担保する。
  validates :date, presence: true
  # 金額は整数・int4 範囲に限定（"abc"→0 の無音変換・小数切り捨て・桁あふれ 500 を防ぐ）。
  # 負値は返金明細として許容する（CSV 取り込みでも負値があり得る）。
  validates :amount, presence: true,
                     numericality: { only_integer: true,
                                     greater_than_or_equal_to: -2_147_483_648,
                                     less_than_or_equal_to: 2_147_483_647 }
  validates :merchant_name, presence: true

  # 複合FKを張らない方針のため、他ユーザーの category/payment_method への紐づけをモデル層で防ぐ
  # （コントローラの current_user スコープと二層）。
  validate :payment_method_belongs_to_user
  validate :category_belongs_to_user

  scope :not_deleted, -> { where(deleted_at: nil) }
  # 月内の明細（集計用の effective_date で判定）。呼び出し側で not_deleted と合成する。
  scope :in_month, ->(year, month) {
    start_date = Date.new(year, month, 1)
    where(effective_date: start_date...start_date.next_month)
  }

  private
    def payment_method_belongs_to_user
      return if payment_method.nil? || user_id.nil?

      errors.add(:payment_method, :invalid) if payment_method.user_id != user_id
    end

    def category_belongs_to_user
      return if category.nil? || user_id.nil?

      errors.add(:category, :invalid) if category.user_id != user_id
    end
end

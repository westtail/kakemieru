# 明細（取り込み・手動入力の1件）。
# - date/amount は原本（不変）。訂正は amount_override/date_override に入れる。
# - effective_amount/effective_date は DB の STORED 生成カラム（COALESCE(override, 原本)）で、
#   集計・グラフ・月絞り込みは必ずこちらを使う。Rails からは書き込まない（読み取り専用）。
# - import_id = NULL は手動入力、category_id = NULL は未分類。
# - 取り消しは物理削除せず deleted_at（ソフトデリート）で行う。
# == Schema Information
#
# Table name: transactions
#
#  id                :bigint           not null, primary key
#  amount            :integer          not null
#  amount_override   :integer
#  date              :date             not null
#  date_override     :date
#  deleted_at        :datetime
#  description       :string
#  effective_amount  :integer
#  effective_date    :date
#  merchant_name     :string(255)      not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  category_id       :bigint
#  import_id         :bigint
#  payment_method_id :bigint           not null
#  user_id           :bigint           not null
#
# Indexes
#
#  index_transactions_on_import_id                   (import_id)
#  index_transactions_on_user_active_category        (user_id,deleted_at,category_id,effective_date)
#  index_transactions_on_user_active_effective_date  (user_id,deleted_at,effective_date)
#  index_transactions_on_user_active_payment_method  (user_id,deleted_at,payment_method_id)
#  index_transactions_on_user_merchant_name          (user_id,merchant_name)
#
# Foreign Keys
#
#  fk_rails_...  (category_id => categories.id) ON DELETE => nullify
#  fk_rails_...  (import_id => imports.id)
#  fk_rails_...  (payment_method_id => payment_methods.id)
#  fk_rails_...  (user_id => users.id)
#
class Transaction < ApplicationRecord
  # date/amount は原本で不変。訂正は *_override に入れる。通常の更新（update/update!）で
  # 変更しようとすると ReadonlyAttributeError（Rails 8: raise_on_assign_to_attr_readonly）。
  # update_all / 生 SQL は対象外（アプリ層の防止）。
  attr_readonly :date, :amount

  # 金額（原本・訂正値）は整数・int4 範囲に限定する。
  AMOUNT_NUMERICALITY = {
    only_integer: true,
    greater_than_or_equal_to: -2_147_483_648,
    less_than_or_equal_to: 2_147_483_647
  }.freeze

  belongs_to :user
  belongs_to :payment_method
  belongs_to :import, optional: true
  belongs_to :category, optional: true

  # user_id / payment_method_id の必須は belongs_to（既定で必須）が担保する。
  validates :date, presence: true
  # 金額は整数・int4 範囲に限定（"abc"→0 の無音変換・小数切り捨て・桁あふれ 500 を防ぐ）。
  # 負値は返金明細として許容する（CSV 取り込みでも負値があり得る）。
  validates :amount, presence: true, numericality: AMOUNT_NUMERICALITY
  # 訂正値も同様に検証（nil = 訂正なし）。無効値の無音変換・生成カラムの誤フォールバックを防ぐ。
  validates :amount_override, numericality: AMOUNT_NUMERICALITY, allow_nil: true
  validates :merchant_name, presence: true, length: { maximum: 255 }

  # 複合FKを張らない方針のため、他ユーザーの user 資源への紐づけをモデル層で防ぐ
  # （コントローラの current_user スコープと二層）。
  validate :payment_method_belongs_to_user
  validate :category_belongs_to_user
  validate :import_belongs_to_user
  validate :date_override_is_valid_date

  # 訂正値（金額 or 日付の override）を持つか。一覧の「訂正」バッジ判定に使う。
  def corrected?
    amount_override.present? || date_override.present?
  end

  # 取り消し（ソフトデリート）。物理削除せず deleted_at をセットする。
  def soft_delete!
    update!(deleted_at: Time.current)
  end

  scope :not_deleted, -> { where(deleted_at: nil) }
  # 月内の明細（集計用の effective_date で判定）。呼び出し側で not_deleted と合成する。
  scope :in_month, ->(year, month) {
    start_date = Date.new(year, month, 1)
    where(effective_date: start_date...start_date.next_month)
  }
  # 店舗名の前方一致。LIKE のワイルドカード（% _）はエスケープする。
  scope :merchant_prefix, ->(keyword) {
    where("merchant_name LIKE ?", "#{sanitize_sql_like(keyword)}%")
  }

  private
    def payment_method_belongs_to_user
      return if payment_method.nil? || user.nil?

      errors.add(:payment_method, :invalid) if payment_method.user_id != user_id
    end

    def category_belongs_to_user
      return if user.nil?
      return if category_id.blank? # 未分類（nil）は許可

      # category は optional のため存在検証されない。実在しない id はここで弾かないと
      # DB の FK 違反で 500 になる（一覧を開いたままカテゴリ削除→古い option 選択のレース）。
      errors.add(:category, :invalid) if category.nil? || category.user_id != user_id
    end

    def import_belongs_to_user
      return if import.nil? || user.nil?

      errors.add(:import, :invalid) if import.user_id != user_id
    end

    # date_override に日付として不正な値（"abc" 等）が渡ると Rails は nil にキャストしてしまい、
    # 「訂正なし」と区別できない。型変換前の値が非空なのにキャスト後 nil なら不正日付として弾く。
    def date_override_is_valid_date
      raw = read_attribute_before_type_cast(:date_override)
      errors.add(:date_override, :invalid) if raw.present? && date_override.nil?
    end
end

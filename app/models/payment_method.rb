# ユーザーごとの支払方法。
# - 現金（payment_type: cash）: 登録時に1件自動生成。削除不可・名前変更のみ可。
# - それ以外: ユーザーが自由に追加・名前/種別変更・削除できる。
# has_many :transactions（S7）/ :imports（S5）は関連先が作られてから追加する（ADR-0025）。
class PaymentMethod < ApplicationRecord
  belongs_to :user

  # アプリ初の enum。値は PaymentMethodCatalog に一元化。DBの CHECK 制約と二重で守る。
  # validate: true で不正値/未設定は ArgumentError ではなくバリデーションエラー（422）にする。
  enum :payment_type, PaymentMethodCatalog::TYPES.index_with(&:itself), validate: true

  validates :name, presence: true, uniqueness: { scope: :user_id }
  validates :payment_type, presence: true

  scope :active, -> { where(archived_at: nil) }
  scope :archived, -> { where.not(archived_at: nil) }

  # 登録時に現金を1件生成する（#21）。
  def self.create_default_for(user)
    user.payment_methods.create!(name: PaymentMethodCatalog::DEFAULT_CASH_NAME, payment_type: "cash")
  end
end

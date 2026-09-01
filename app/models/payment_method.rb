# ユーザーごとの支払方法。
# - 現金（payment_type: cash）: 登録時に1件自動生成。削除不可・名前変更のみ可。
# - それ以外: ユーザーが自由に追加・名前/種別変更・削除できる。
# has_many :transactions / :imports は関連先が作られてから追加する。
# == Schema Information
#
# Table name: payment_methods
#
#  id           :bigint           not null, primary key
#  archived_at  :datetime
#  name         :string           not null
#  payment_type :string           not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  user_id      :bigint           not null
#
# Indexes
#
#  index_payment_methods_on_user_id_and_archived_at  (user_id,archived_at)
#  index_payment_methods_on_user_id_and_name         (user_id,name) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id) ON DELETE => cascade
#
class PaymentMethod < ApplicationRecord
  belongs_to :user

  # アプリ初の enum。値は PaymentMethodCatalog に一元化。DBの CHECK 制約と二重で守る。
  # validate: true で不正値/未設定は ArgumentError ではなくバリデーションエラー（422）にする。
  enum :payment_type, PaymentMethodCatalog::TYPES.index_with(&:itself), validate: true

  validates :name, presence: true, uniqueness: { scope: :user_id }
  validates :payment_type, presence: true

  # 取り込み履歴を持つ支払方法は物理削除させない（履歴保護。DATABASE_DESIGN の RESTRICT）。
  has_many :imports, dependent: :restrict_with_exception
  # 明細を持つ支払方法の物理削除は分岐前の安全網として例外化（通常はコントローラで archive! に分岐）。
  # 退会カスケードでは transactions が先に destroy されるため競合しない。
  has_many :transactions, dependent: :restrict_with_exception

  scope :active, -> { where(archived_at: nil) }
  scope :archived, -> { where.not(archived_at: nil) }

  # 明細を持つ支払方法は物理削除せずアーカイブする（DATABASE_DESIGN の削除ポリシー）。
  # before_destroy 内で update! + throw :abort すると destroy のトランザクションごと
  # ロールバックされ archived_at が保存されないため、削除/アーカイブの分岐はコントローラで行う。
  # 履歴（明細 or 取り込み）を持つ支払方法は物理削除でなくアーカイブする。
  # imports も restrict のため、transactions が無くても imports があれば削除は失敗する。
  def archivable?
    transactions.exists? || imports.exists?
  end

  def archive!
    update!(archived_at: Time.current)
  end

  # 登録時に現金を1件生成する。
  def self.create_default_for(user)
    user.payment_methods.create!(name: PaymentMethodCatalog::DEFAULT_CASH_NAME, payment_type: "cash")
  end
end

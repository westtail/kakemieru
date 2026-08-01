class User < ApplicationRecord
  # 権限昇格の多層防御: strong parameters で admin を permit しないことに加え、
  # 作成後の AR 経由での admin 変更を禁止する。
  # 注意: Rails 8（load_defaults 8.0）では readonly 属性への代入は例外（ReadonlyAttributeError）。
  # 管理者への昇格が必要なときは `user.update_column(:admin, true)`（バリデーション/コールバック無し）で行う。
  attr_readonly :admin

  has_secure_password
  has_many :sessions, dependent: :destroy

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  # email_address は normalizes で小文字化されるため、uniqueness はデフォルト
  # （大文字小文字を区別）のままで実質 case-insensitive になり、unique index を効率よく使える。
  validates :email_address, presence: true,
                            uniqueness: true,
                            format: { with: URI::MailTo::EMAIL_REGEXP }

  # has_secure_password は presence と72バイト上限のみ検証するため最小長を補う。
  # allow_nil: true で「パスワード未変更の更新」を許容する（作成時の presence は has_secure_password が担保）。
  validates :password, length: { minimum: 8 }, allow_nil: true
end

class User < ApplicationRecord
  # 権限昇格の多層防御（認可制御そのものではなく「うっかり更新」の防止）:
  # - 作成時: strong parameters が admin を permit しない（create 経路の唯一の砦）。
  # - 更新時: attr_readonly により、通常のモデル更新（update / update! / update_column）で
  #   admin を変更しようとすると ReadonlyAttributeError（Rails 8: raise_on_assign_to_attr_readonly=true）。
  # 意図的な昇格は relation 経由の一括更新（例: `User.where(id: id).update_all(admin: true)`）で行う
  # （update_all / 生 SQL は attr_readonly を経由しないため）。
  attr_readonly :admin

  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :categories, dependent: :destroy
  # imports は payment_methods より先に destroy されるよう先に宣言する（退会時のカスケードで
  # payment_methods の restrict にかからないようにするため）。
  has_many :imports, dependent: :destroy
  has_many :payment_methods, dependent: :destroy

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

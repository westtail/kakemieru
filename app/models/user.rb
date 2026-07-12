class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  # email_address は normalizes で小文字化されるため、uniqueness はデフォルト
  # （大文字小文字を区別）のままで実質 case-insensitive になり、unique index を効率よく使える。
  validates :email_address, presence: true,
                            uniqueness: true,
                            format: { with: URI::MailTo::EMAIL_REGEXP }
end

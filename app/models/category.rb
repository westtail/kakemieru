# ユーザーごとのカテゴリ。
# - 初期カテゴリ: category_key あり（テンプレ由来）。名前変更のみ可・削除不可。
# - 独自カテゴリ: category_key が NULL。追加・名前変更・削除すべて可。
# has_many :transactions / dependent: :nullify は Transaction を作る S7 で追加する（ADR-0024）。
# == Schema Information
#
# Table name: categories
#
#  id           :bigint           not null, primary key
#  category_key :string
#  name         :string           not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  user_id      :bigint           not null
#
# Indexes
#
#  index_categories_on_user_id_and_category_key  (user_id,category_key) UNIQUE WHERE (category_key IS NOT NULL)
#  index_categories_on_user_id_and_name          (user_id,name) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id) ON DELETE => cascade
#
class Category < ApplicationRecord
  belongs_to :user

  validates :name, presence: true, uniqueness: { scope: :user_id }

  # カテゴリ削除時に紐づく明細の category_id を NULL（未分類）にする。DB の FK on_delete: :nullify と二層。
  has_many :transactions, dependent: :nullify

  scope :initial, -> { where.not(category_key: nil) }
  scope :custom, -> { where(category_key: nil) }

  # 初期カテゴリ（テンプレ由来）かどうか。
  def initial?
    category_key.present?
  end

  # 登録時にテンプレート全件をこのユーザーのカテゴリへコピーする（#21 の一部）。
  # 検証済みのテンプレ由来データなので insert_all で一括投入する。
  def self.copy_templates_to(user)
    now = Time.current
    rows = CategoryTemplate.order(:id).map do |template|
      {
        user_id: user.id,
        category_key: template.category_key,
        name: template.name,
        created_at: now,
        updated_at: now
      }
    end
    insert_all(rows) if rows.any?
  end
end

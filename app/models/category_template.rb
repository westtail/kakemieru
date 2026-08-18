# システム共通のカテゴリテンプレート（不変・ユーザー編集不可）。
# 登録時に各ユーザーの categories へコピーされる（Category.copy_templates_to）。
class CategoryTemplate < ApplicationRecord
  validates :category_key, presence: true, uniqueness: true
  validates :name, presence: true
end

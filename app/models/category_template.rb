# システム共通のカテゴリテンプレート（不変・ユーザー編集不可）。
# 登録時に各ユーザーの categories へコピーされる（Category.copy_templates_to）。
# == Schema Information
#
# Table name: category_templates
#
#  id           :bigint           not null, primary key
#  category_key :string           not null
#  name         :string           not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#
# Indexes
#
#  index_category_templates_on_category_key  (category_key) UNIQUE
#
class CategoryTemplate < ApplicationRecord
  validates :category_key, presence: true, uniqueness: true
  validates :name, presence: true
end

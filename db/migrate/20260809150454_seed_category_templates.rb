class SeedCategoryTemplates < ActiveRecord::Migration[8.0]
  # category_templates の初期12件を投入する。seeds.rb は既存の本番DBでは自動実行されない
  # ため、db:migrate で確実に本番へ入るデータ投入マイグレーションとして持つ（ADR-0024）。
  #
  # 履歴マイグレーションは不変のスナップショットであるべきなので、アプリの定数
  # （CategoryCatalog::DEFAULTS）は参照せず、この時点の固定データを内包する。
  # 以後のカテゴリ追加/変更は新しいマイグレーションで行う。
  # 投入はアプリ本体のモデルに依存しないマイグレーション内ローカルモデルで行う。
  class CategoryTemplate < ActiveRecord::Base
  end

  DEFAULTS = [
    { category_key: "food",          name: "食費" },
    { category_key: "dining_out",    name: "外食" },
    { category_key: "transport",     name: "交通費" },
    { category_key: "daily",         name: "日用品" },
    { category_key: "entertainment", name: "娯楽" },
    { category_key: "clothing",      name: "衣服・美容" },
    { category_key: "medical",       name: "医療・健康" },
    { category_key: "utilities",     name: "光熱費" },
    { category_key: "communication", name: "通信費" },
    { category_key: "subscription",  name: "サブスク" },
    { category_key: "education",     name: "教育" },
    { category_key: "other",         name: "その他" }
  ].freeze

  def up
    DEFAULTS.each do |c|
      # 冪等: 既にあれば作らない（2回流しても12件のまま）。
      CategoryTemplate.find_or_create_by!(category_key: c[:category_key]) { |t| t.name = c[:name] }
    end
  end

  def down
    CategoryTemplate.where(category_key: DEFAULTS.map { |c| c[:category_key] }).delete_all
  end
end

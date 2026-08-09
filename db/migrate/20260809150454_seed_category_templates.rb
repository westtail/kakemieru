class SeedCategoryTemplates < ActiveRecord::Migration[8.0]
  # category_templates の初期12件を投入する。seeds.rb は既存の本番DBでは自動実行されない
  # ため、db:migrate で確実に本番へ入るデータ投入マイグレーションとして持つ（ADR-0024）。
  # アプリ本体のモデルに依存しないよう、マイグレーション内ローカルのモデルを使う。
  class CategoryTemplate < ActiveRecord::Base
  end

  def up
    CategoryCatalog::DEFAULTS.each do |c|
      # 冪等: 既にあれば作らない（2回流しても12件のまま）。
      CategoryTemplate.find_or_create_by!(category_key: c[:key]) { |t| t.name = c[:name] }
    end
  end

  def down
    CategoryTemplate.where(category_key: CategoryCatalog::DEFAULTS.map { |c| c[:key] }).delete_all
  end
end

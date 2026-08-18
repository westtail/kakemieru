# このファイルは全環境で冪等に実行できること。bin/rails db:seed で流す。
# 本番は SeedCategoryTemplates マイグレーションで確実に投入されるため（ADR-0024）、
# ここは主に development / test での初期データ用（同じ内容を冪等に投入する）。

# カテゴリテンプレート（12件）
CategoryCatalog::DEFAULTS.each do |c|
  CategoryTemplate.find_or_create_by!(category_key: c[:key]) { |t| t.name = c[:name] }
end

# カテゴリの初期テンプレート定義（一元管理）。
# データ投入マイグレーション・db/seeds.rb・テスト から参照する単一の情報源。
# category_key は merchant_classifications（S5）との紐づけキーにもなる。
module CategoryCatalog
  # 順序＝画面や seed で並べたい既定順。
  DEFAULTS = [
    { key: "food",          name: "食費" },
    { key: "dining_out",    name: "外食" },
    { key: "transport",     name: "交通費" },
    { key: "daily",         name: "日用品" },
    { key: "entertainment", name: "娯楽" },
    { key: "clothing",      name: "衣服・美容" },
    { key: "medical",       name: "医療・健康" },
    { key: "utilities",     name: "光熱費" },
    { key: "communication", name: "通信費" },
    { key: "subscription",  name: "サブスク" },
    { key: "education",     name: "教育" },
    { key: "other",         name: "その他" }
  ].freeze
end

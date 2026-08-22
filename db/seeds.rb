# このファイルは全環境で冪等に実行できること。bin/rails db:seed で流す。
# 本番は SeedCategoryTemplates マイグレーションで確実に投入されるため（ADR-0024）、
# ここは主に development / test での初期データ用（同じ内容を冪等に投入する）。

# カテゴリテンプレート（12件）
CategoryCatalog::DEFAULTS.each do |c|
  CategoryTemplate.find_or_create_by!(category_key: c[:key]) { |t| t.name = c[:name] }
end

# 以降は開発時の動作確認用サンプルデータ。development のみ・冪等に投入する。
# 本番/テストには入れない（本番はマイグレーション、テストは FactoryBot を使う）。
return unless Rails.env.development?

# ログイン用の開発ユーザー（dev@example.com / password）。
user = User.find_or_create_by!(email_address: "dev@example.com") do |u|
  u.password = "password"
  u.password_confirmation = "password"
end

# 初期カテゴリ（テンプレ由来）を正規状態へ収束させる。全消し済み・部分欠けでも
# 不足しているキーだけを補い、サンプル明細が未分類化するのを防ぐ。
existing_keys = user.categories.where.not(category_key: nil).pluck(:category_key)
CategoryTemplate.order(:id).each do |template|
  next if existing_keys.include?(template.category_key)

  user.categories.create!(category_key: template.category_key, name: template.name)
end

# 現金（削除不可の特別枠）が無ければ用意する。
PaymentMethod.create_default_for(user) unless user.payment_methods.exists?(payment_type: "cash")

# サンプルのカード類（現金は create_default_for で作成済み）。
user.payment_methods.find_or_create_by!(name: "楽天カード") { |pm| pm.payment_type = "credit" }
user.payment_methods.find_or_create_by!(name: "PayPay") { |pm| pm.payment_type = "qr" }

# 明細は自然キーが無いため、まだ1件も無いときだけ投入して冪等にする。
if user.transactions.none?
  card = user.payment_methods.find_by!(name: "楽天カード")
  cash = user.payment_methods.find_by!(payment_type: "cash")
  category = ->(key) { user.categories.find_by(category_key: key) }

  this_month = Date.current.beginning_of_month
  last_month = this_month.prev_month

  samples = [
    # [基準月, 日, 店舗名, 金額, カテゴリキー, 支払方法]
    [ this_month, 3,  "スーパーマルエツ", 8_200, "food",          card ],
    [ this_month, 5,  "JR東日本",         5_600, "transport",     card ],
    [ this_month, 8,  "セブンイレブン",   3_400, "food",          cash ],
    [ this_month, 12, "ドラッグストア",   2_900, "daily",         card ],
    [ this_month, 18, "Netflix",          1_490, "subscription",  card ],
    [ this_month, 22, "カフェ",             680, nil,             cash ],
    [ last_month, 4,  "スーパーライフ",   6_800, "food",          card ],
    [ last_month, 10, "東京電力",         7_300, "utilities",     card ],
    [ last_month, 15, "ユニクロ",         4_990, "clothing",      card ],
    [ last_month, 25, "居酒屋",           5_200, "dining_out",    cash ]
  ]

  # 途中失敗で一部だけコミットされると、再実行時に none? が false になり補完できない。
  # 全件まとめて投入し、失敗時は投入前の状態へ戻す。
  ActiveRecord::Base.transaction do
    samples.each do |base, day, name, amount, key, payment_method|
      user.transactions.create!(
        payment_method: payment_method,
        category: key && category.call(key),
        date: base + (day - 1).days,
        amount: amount,
        merchant_name: name
      )
    end
  end

  puts "[seed] #{user.email_address} にサンプル明細 #{samples.size} 件を投入しました。"
end

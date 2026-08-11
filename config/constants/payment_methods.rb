# 支払方法の定数（一元管理）。モデルの enum・フォームのセレクト・テストから参照する。
# 履歴マイグレーションの CHECK 制約は不変にするため、この定数は参照せず値を直接書く。
module PaymentMethodCatalog
  # payment_type の全値（enum の定義に使う）。
  TYPES = %w[credit debit e_money qr cash].freeze

  # フォームで選べる種別。現金(cash)は登録時に自動生成される特別枠のため出さない。
  SELECTABLE_TYPES = %w[credit debit e_money qr].freeze

  # 表示用の日本語ラベル。
  LABELS = {
    "credit"  => "クレジットカード",
    "debit"   => "デビットカード",
    "e_money" => "電子マネー",
    "qr"      => "QRコード決済",
    "cash"    => "現金"
  }.freeze

  # 登録時に自動生成する現金の名称。
  DEFAULT_CASH_NAME = "現金"
end

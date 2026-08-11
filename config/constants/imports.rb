# 取り込み（imports）の定数。モデルの enum・テストから参照する。
# 履歴マイグレーションの CHECK 制約は不変にするため、この定数は参照せず値を直接書く。
module ImportCatalog
  # source_type の全値（enum の定義に使う）。フェーズ1は csv のみ運用。
  SOURCE_TYPES = %w[csv ocr api manual_bulk].freeze
end

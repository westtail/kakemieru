# 取り込み操作の単位（CSV 1ファイル = 1 Import）。同一ユーザー内で file_hash を一意にして
# 同じ内容の二重取り込みを防ぐ。Import は物理削除しない方針（取り消しは transactions の
# ソフトデリートで行う）。has_many :transactions は transactions を作る S7 で追加する。
class Import < ApplicationRecord
  belongs_to :user
  belongs_to :payment_method

  enum :source_type, ImportCatalog::SOURCE_TYPES.index_with(&:itself), validate: true

  validates :source_type, presence: true
  validates :file_hash, presence: true, uniqueness: { scope: :user_id }
  # ファイル由来（csv/ocr/api）は取り込み元参照が必須。手動一括入力のみ省略可。
  validates :source_ref, presence: true, unless: -> { manual_bulk? }
end

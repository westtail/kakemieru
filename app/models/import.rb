# 取り込み操作の単位（CSV 1ファイル = 1 Import）。同一ユーザー内で file_hash を一意にして
# 同じ内容の二重取り込みを防ぐ。Import は物理削除しない方針（取り消しは transactions の
# ソフトデリートで行う）。has_many :transactions は transactions を作る S7 で追加する。
# == Schema Information
#
# Table name: imports
#
#  id                :bigint           not null, primary key
#  file_hash         :string           not null
#  imported_at       :datetime
#  row_count         :integer          default(0), not null
#  source_ref        :string
#  source_type       :string           not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  payment_method_id :bigint           not null
#  user_id           :bigint           not null
#
# Indexes
#
#  index_imports_on_payment_method_id      (payment_method_id)
#  index_imports_on_user_id_and_file_hash  (user_id,file_hash) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (payment_method_id => payment_methods.id)
#  fk_rails_...  (user_id => users.id) ON DELETE => cascade
#
class Import < ApplicationRecord
  belongs_to :user
  belongs_to :payment_method

  enum :source_type, ImportCatalog::SOURCE_TYPES.index_with(&:itself), validate: true

  # 取り込み済みの明細を持つ Import は物理削除させない（取り消しは transactions のソフトデリート）。
  has_many :transactions, dependent: :restrict_with_exception

  validates :source_type, presence: true
  validates :file_hash, presence: true, uniqueness: { scope: :user_id }
  # ファイル由来（csv/ocr/api）は取り込み元参照が必須。手動一括入力のみ省略可。
  validates :source_ref, presence: true, unless: -> { manual_bulk? }
  # 支払方法が同じユーザーのものであることをモデル層でも担保する（S6 のコントローラが
  # current_user スコープを取りこぼしても他ユーザーの payment_method に紐づけさせない）。
  validate :payment_method_belongs_to_user

  private
    def payment_method_belongs_to_user
      return if payment_method.nil? || user_id.nil?

      errors.add(:payment_method, :invalid) if payment_method.user_id != user_id
    end
end

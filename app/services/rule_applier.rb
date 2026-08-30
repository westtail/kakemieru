# 店舗ルール（ADR-0047）と特別ルール（ADR-0048）を未分類の明細へ一括適用する。「更新実行」
# ボタンから呼ぶ。対象は本人の未削除・未分類（category_id NULL）明細のみで、手動で付けた
# カテゴリは上書きしない。特別ルールが一致し note があれば description に追記する。更新件数を返す。
class RuleApplier
  def initialize(user:)
    @user = user
  end

  def call
    matcher = RuleMatcher.new(user: @user, use_merchant: true, use_special: true)

    # note 無しはカテゴリ別にまとめて update_all（高速路）。note 有りは description を
    # 明細ごとに追記する必要があるため行単位で更新する。
    ids_by_category = Hash.new { |hash, key| hash[key] = [] }
    noted = []

    @user.transactions.not_deleted.where(category_id: nil)
         .pluck(:id, :merchant_name, :effective_amount, :effective_date, :description)
         .each do |id, merchant_name, amount, date, description|
      result = matcher.match(merchant_name: merchant_name, amount: amount, date: date)
      next if result.nil?

      if result.note.present?
        noted << { id: id, category_id: result.category_id, description: DescriptionNote.append(description, result.note) }
      else
        ids_by_category[result.category_id] << id
      end
    end

    # 途中の InvalidForeignKey レース（対象カテゴリの同時削除）で部分適用が残らないよう原子的に。
    now = Time.current
    ActiveRecord::Base.transaction do
      count = ids_by_category.sum do |category_id, ids|
        @user.transactions.where(id: ids).update_all(category_id: category_id, updated_at: now)
      end
      noted.each do |row|
        count += @user.transactions.where(id: row[:id])
                      .update_all(category_id: row[:category_id], description: row[:description], updated_at: now)
      end
      count
    end
  end
end

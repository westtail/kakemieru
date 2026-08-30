# おすすめ店舗ルール（ADR-0047）。ユーザーの明細（transactions）を 店舗 × カテゴリ で集計し、
# 「この店はいつもこのカテゴリ」という候補を提示する。永続テーブルは持たず都度算出＝常に最新。
#
# 出す条件:
# - 同じ店舗を最頻カテゴリで MIN_COUNT 回以上分類した実績があること（1回きりのノイズは出さない）
# - すでに店舗ルール登録済みの店舗は除外（未登録の店舗だけ提案する）
# 並び順は件数の多い順（同数は店舗名昇順で安定化）。店舗名は正規化して集約し、表示は代表の生表記。
class MerchantRecommendations
  Recommendation = Struct.new(:merchant_name, :category_id, :category_name, :count, keyword_init: true)

  MIN_COUNT = 2

  def initialize(user:)
    @user = user
  end

  def call
    registered = @user.merchant_classifications.pluck(:merchant_name).to_set # 正規化済み
    category_names = @user.categories.pluck(:id, :name).to_h

    tallies = tally_by_merchant(registered)

    recommendations = tallies.filter_map do |_key, entry|
      category_id, count = entry[:categories].min_by { |cid, c| [ -c, cid ] } # 最頻→同数は id 昇順
      next if count < MIN_COUNT

      name = category_names[category_id]
      next if name.nil? # 削除済みカテゴリは提案しない

      display = entry[:raw].min_by { |raw, c| [ -c, raw ] }.first # 代表表記（最頻の生表記）
      Recommendation.new(merchant_name: display, category_id: category_id, category_name: name, count: count)
    end

    recommendations.sort_by { |r| [ -r.count, r.merchant_name ] }
  end

  private
    # 正規化した店舗名ごとに、カテゴリ別件数と生表記別件数を数える（登録済み・未分類は除外）。
    def tally_by_merchant(registered)
      tallies = Hash.new { |hash, key| hash[key] = { categories: Hash.new(0), raw: Hash.new(0) } }

      @user.transactions.not_deleted.where.not(category_id: nil)
           .pluck(:merchant_name, :category_id).each do |raw, category_id|
        key = CategoryClassifier.normalize(raw)
        next if key.blank? || registered.include?(key)

        tallies[key][:categories][category_id] += 1
        tallies[key][:raw][raw] += 1
      end

      tallies
    end
end

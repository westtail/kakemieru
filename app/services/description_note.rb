# 特別ルールの note を明細 description へ「 / 」区切りで冪等に追記する。
# 既に同じ note を含む description には足さない（未分類へ戻して再適用しても二重付記しない）。
# 原本の description は残す。RuleApplier / CsvImporter が共有する。
module DescriptionNote
  def self.append(description, note)
    return description if note.blank?

    base = description.to_s
    return base if base.include?(note)

    [ base.presence, note ].compact.join(" / ")
  end
end

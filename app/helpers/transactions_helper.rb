module TransactionsHelper
  # 明細一覧のソート可能なヘッダーリンク（#147）。クリックで昇順、同じ列を再クリックで降順に
  # トグルする。現在の絞り込み条件（月/カテゴリ/キーワード）は維持したまま sort/direction を差し替える。
  def sort_header(label, key)
    active = @sort == key
    next_direction = (active && @direction == "asc") ? "desc" : "asc"
    indicator = active ? (@direction == "asc" ? "▲" : "▼") : "↕"
    classes = active ? "font-semibold text-gray-900" : "text-gray-600 hover:text-gray-900"

    # 現在の絞り込み条件だけを引き継ぐ（想定外パラメータや sort キー重複を持ち回らない）。
    carried = request.query_parameters.slice("month", "category", "q")
    link_to transactions_path(carried.merge(sort: key, direction: next_direction)),
            class: "#{classes} no-underline inline-flex items-center gap-1",
            "aria-label": "#{label}で並べ替え" do
      safe_join([ label, content_tag(:span, indicator, class: "text-xs #{'text-gray-400' unless active}") ])
    end
  end
end

module ApplicationHelper
  # グローバルナビの1項目。現在のコントローラが controllers に含まれれば「現在地」として
  # 強調表示（.nav-link-active + aria-current="page"）する。
  def nav_link(label, path, *controllers, **options)
    active = controllers.include?(controller_name)
    link_to label, path,
            class: active ? "nav-link-active" : "nav-link",
            "aria-current": (active ? "page" : nil),
            **options
  end

  # ナビの現在地判定だけ欲しい箇所（ドロップダウンのボタン等）で使う。
  def nav_active?(*controllers)
    controllers.include?(controller_name)
  end
end

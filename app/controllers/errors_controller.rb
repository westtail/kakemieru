# ブランド化したエラーページ。config.exceptions_app = routes 経由で例外時にも使われる。
# エラーページは認証を要求しない（未ログインでもログイン画面にリダイレクトしない）。
class ErrorsController < ApplicationController
  allow_unauthenticated_access
  # エラー描画は常に通したいので CSRF 検証も無効化する（POST が例外→/500 へディスパッチされても
  # トークン検証で再 raise しないように）。状態変更は無く安全。
  skip_forgery_protection
  # DB/セッションに依存しない最小レイアウトを使う（エラー時でも確実に描画するため）。
  layout "error"

  def not_found
    render_error("404", :not_found)
  end

  def unprocessable_entity
    render_error("422", :unprocessable_entity)
  end

  def internal_server_error
    render_error("500", :internal_server_error)
  end

  private
    # HTML はエラービュー（app/views/errors/<code>.html.erb）を、それ以外の形式は
    # ボディ無しで status のみ返す（描画失敗の連鎖を防ぐ）。
    def render_error(template, status)
      respond_to do |format|
        format.html { render template, status: status }
        format.any  { head status }
      end
    end
end

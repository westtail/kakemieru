require "rails_helper"

# E2E がネットワークの機嫌で赤くならないことを守るガード。
#
# CI はインターネットに出られるため、spec/support/capybara.rb の遮断設定が外れても
# 他の spec は緑のままになり、flaky な状態へ静かに戻ってしまう。そこで「設定が在ること」と
# 「実際に遮断されること」の両方をここで検証する。方針は capybara.rb のコメントを参照。
RSpec.describe "E2E ドライバの外部通信遮断", type: :feature do
  # cuprite の準公開 API。cuprite 側で改名されればこの spec が NoMethodError で落ちる。
  # 遮断が無言で外れるより、ここで騒がしく落ちる方が望ましい。
  def allowlist
    Capybara.current_session.driver.options[:url_whitelist]
  end

  def allowed?(url)
    allowlist.any? { |pattern| url.match?(pattern) }
  end

  describe "設定" do
    it "許可リストが設定されている（未設定だと素通しになる）" do
      expect(allowlist).to be_present
    end

    it "アプリ自身のオリジンは許可する" do
      aggregate_failures do
        [ "http://web:4444/transactions", "http://127.0.0.1:3000/", "http://localhost:4444/imports" ].each do |url|
          expect(allowed?(url)).to be(true), "#{url} が遮断されている"
        end
      end
    end

    it "外部ホストもホスト名を偽装した URL も許可しない" do
      aggregate_failures do
        [
          "https://fonts.googleapis.com/css2?family=Roboto+Mono",
          "https://fonts.gstatic.com/s/robotomono/v23/font.woff2",
          "https://example.com/",
          "http://web.evil.com/",          # 先頭一致を外すと通ってしまうケース
          "http://localhost.evil.com/x",
          "http://web:4444@evil.com/"      # userinfo による偽装
        ].each do |url|
          expect(allowed?(url)).to be(false), "#{url} が許可されている"
        end
      end
    end
  end

  describe "振る舞い" do
    # 正規表現の検証だけでは「cuprite がオプションを無視し始めた」ケースを取り逃がすため、
    # 実際にブラウザを動かして abort されたことを確認する。
    it "LP が参照する外部フォントのリクエストが実際に abort される" do
      visit "/"

      font_requests = page.driver.browser.network.traffic.select do |exchange|
        exchange.request&.url&.start_with?("https://fonts.googleapis.com")
      end

      expect(font_requests).not_to be_empty, "LP が外部フォントを参照していない（前提が変わった可能性）"
      expect(font_requests).to all(be_blocked)
    end
  end
end

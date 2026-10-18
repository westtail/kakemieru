require "rails_helper"

# E2E がネットワークの機嫌で赤くならないことを守るガード。
#
# CI はインターネットに出られるため、spec/support/capybara.rb の遮断設定が外れても
# 他の spec は緑のままになり、flaky な状態へ静かに戻ってしまう。そこで「設定が在ること」と
# 「実際に遮断されること」の両方をここで検証する。方針は ADR-0023 セクション6 を参照。
RSpec.describe "E2E ドライバの外部通信遮断", type: :feature do
  # Capybara::Cuprite::Driver の公開リーダー。ブラウザを起動せずに読める。
  # cuprite 側でオプション名が変われば NoMethodError で落ちるが、遮断が無言で外れるより良い。
  def allowlist
    Capybara.current_session.driver.options[:url_whitelist]
  end

  def allowed?(url)
    allowlist.any? { |pattern| url.match?(pattern) }
  end

  # ここで見るのは正規表現の意味論だけ。cuprite が実際に適用したか（配線）は「振る舞い」側で担保する。
  describe "設定" do
    it "許可リストが設定されている（未設定だと素通しになる）" do
      expect(allowlist).to be_present
    end

    it "アプリ自身のオリジンは許可する" do
      # ループバックは設定で常に許可している（ローカル Chrome モード = CI 用）。
      # アプリのホストは CAPYBARA_APP_HOST で変えられるので、期待値は実際の設定から組み立てる。
      # ここをハードコードすると、設定が正しいのに env を変えただけで落ちてしまう。
      urls = [ "http://127.0.0.1:3000/", "http://localhost:4444/imports" ]
      # ローカル Chrome モード（CI）では app_host が nil なので、この1件は検証対象から外れる。
      # その場合もループバック2件で「アプリのオリジンが通ること」は担保される。
      urls << "#{Capybara.app_host}/transactions" if Capybara.app_host

      aggregate_failures do
        urls.each do |url|
          expect(allowed?(url)).to be(true), "#{url} が遮断されている"
        end
      end
    end

    it "外部ホストもホスト名を偽装した URL も許可しない" do
      aggregate_failures do
        [
          "https://fonts.googleapis.com/css2?family=Roboto+Mono",
          "https://example.com/",
          "http://web.evil.com/",          # 先頭一致を外すと通ってしまうケース
          "http://localhost.evil.com/x",
          "http://web:4444@evil.com/"      # userinfo でアプリのホスト名を騙る偽装（env に依らず遮断されるべき）
        ].each do |url|
          expect(allowed?(url)).to be(false), "#{url} が許可されている"
        end
      end
    end
  end

  describe "振る舞い" do
    # 検証用のリクエストはページ自身から起こす。特定のビュー（LP のフォント <link> など）に
    # 依存させると、フォントを self-host した時点で遮断機構が健全なままこの spec が落ちる。
    it "ページから外部ホストへ出たリクエストが実際に abort される" do
      visit "/"

      result = page.evaluate_async_script(<<~JS)
        const done = arguments[0];
        fetch("https://example.com/blocked-probe")
          .then(() => done("allowed"))
          .catch(() => done("rejected"));
      JS
      expect(result).to eq("rejected")

      # 「ネットワーク障害で失敗した」のではなく「クライアントが遮断した」ことまで確認する。
      # これが無いと、オフライン環境では遮断が外れていても緑になってしまう。
      probes = page.driver.browser.network.traffic.select do |exchange|
        exchange.request&.url&.include?("blocked-probe")
      end
      expect(probes).not_to be_empty
      expect(probes).to all(be_blocked)
    end
  end
end

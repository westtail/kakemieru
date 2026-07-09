# Capybara + Cuprite（Ferrum 経由で Chrome を CDP 操作）の設定。
# 詳細な方針は docs/decisions/0023-e2e-test-environment.md を参照。
require "capybara/rspec"
require "capybara/cuprite"
require "resolv"

# テストプロセス（web コンテナ）内で Capybara が Puma を起動し、
# 別コンテナの Chrome からアクセスさせるためのネットワーク設定。
# - server_host: 全 IF で待受け、chrome コンテナから到達可能にする
# - app_host:    chrome から web コンテナ名で解決させる
CAPYBARA_SERVER_PORT = Integer(ENV.fetch("CAPYBARA_SERVER_PORT", "4444"))
CAPYBARA_APP_HOST = ENV.fetch("CAPYBARA_APP_HOST", "web")

# Chrome は DNS リバインディング対策でホスト名の CDP アクセスを拒否する
# （"Host header is not an IP address or localhost"）。そのため接続先を IP に解決する。
CHROME_HOST = ENV.fetch("CHROME_HOST", "chrome")
CHROME_PORT = ENV.fetch("CHROME_PORT", "9222")
REMOTE_CHROME_URL = ENV.fetch("CHROME_URL") do
  ip = begin
    Resolv.getaddress(CHROME_HOST)
  rescue Resolv::ResolvError
    CHROME_HOST
  end
  "http://#{ip}:#{CHROME_PORT}"
end

Capybara.server = :puma, { Silent: true }
Capybara.server_host = "0.0.0.0"
Capybara.server_port = CAPYBARA_SERVER_PORT
Capybara.app_host = "http://#{CAPYBARA_APP_HOST}:#{CAPYBARA_SERVER_PORT}"
# 失敗時のデバッグに便利な待機・保存設定
Capybara.default_max_wait_time = 5
Capybara.save_path = Rails.root.join("tmp/screenshots")

Capybara.register_driver(:cuprite) do |app|
  Capybara::Cuprite::Driver.new(
    app,
    # 別コンテナの Chrome にリモート接続する（プロセスを自前起動しない）
    url: REMOTE_CHROME_URL,
    window_size: [1200, 800],
    process_timeout: 20,
    timeout: 20,
    # CI やコンテナでの安定動作用フラグ
    browser_options: { "no-sandbox" => nil }
  )
end

Capybara.default_driver = :cuprite
Capybara.javascript_driver = :cuprite

RSpec.configure do |config|
  # feature spec 失敗時にスクリーンショットを保存する
  config.after(:each, type: :feature) do |example|
    next unless example.exception

    meta = example.metadata
    filename = File.basename(meta[:file_path]).sub(/\.rb$/, "")
    line = meta[:line_number]
    screenshot = Rails.root.join("tmp/screenshots", "#{filename}-#{line}.png")
    page.save_screenshot(screenshot) if page.respond_to?(:save_screenshot)
    $stderr.puts "[Capybara] スクリーンショットを保存しました: #{screenshot}"
  rescue StandardError => e
    $stderr.puts "[Capybara] スクリーンショット保存に失敗: #{e.message}"
  end
end

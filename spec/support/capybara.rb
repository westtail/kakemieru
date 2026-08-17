# Capybara + Cuprite（Ferrum 経由で Chrome を CDP 操作）の設定。
# 詳細な方針は docs/decisions/0023-e2e-test-environment.md を参照。
#
# 2 モード:
# - リモート: 別コンテナの Chrome に CDP 接続（ローカル Docker。web コンテナに Chrome が無い）。
#   docker-compose.override.yml が CHROME_HOST を渡すことで有効化される。
# - ローカル: 同一ホストの Chrome を Cuprite が起動（CI 等・Chrome が入っている環境）。
require "capybara/rspec"
require "capybara/cuprite"
require "resolv"

remote_chrome = ENV["CHROME_URL"].presence || ENV["CHROME_HOST"].presence

Capybara.server = :puma, { Silent: true }
Capybara.default_max_wait_time = 5
Capybara.save_path = Rails.root.join("tmp/screenshots")
# aria-label を持つコントロール（一覧のカテゴリ select 等）をアクセシブル名で探せるようにする。
Capybara.enable_aria_label = true

cuprite_options = {
  window_size: [ 1200, 800 ],
  process_timeout: 20,
  timeout: 20,
  browser_options: { "no-sandbox" => nil, "disable-dev-shm-usage" => nil }
}

if remote_chrome
  # テストプロセスの Puma を全 IF で待受けし、Chrome からコンテナ名で解決させる。
  # Chrome は DNS リバインディング対策でホスト名の CDP を拒否するため、接続先は IP に解決する。
  server_port = Integer(ENV.fetch("CAPYBARA_SERVER_PORT", "4444"))
  Capybara.server_host = "0.0.0.0"
  Capybara.server_port = server_port
  Capybara.app_host = "http://#{ENV.fetch('CAPYBARA_APP_HOST', 'web')}:#{server_port}"

  chrome_url = ENV.fetch("CHROME_URL") do
    host = ENV.fetch("CHROME_HOST", "chrome")
    ip = begin
      Resolv.getaddress(host)
    rescue Resolv::ResolvError
      host
    end
    "http://#{ip}:#{ENV.fetch('CHROME_PORT', '9222')}"
  end

  Capybara.register_driver(:cuprite) do |app|
    Capybara::Cuprite::Driver.new(app, url: chrome_url, **cuprite_options)
  end
else
  # 同一ホストで Cuprite が Chrome を起動する（server_host/app_host は Capybara 既定の localhost）。
  Capybara.register_driver(:cuprite) do |app|
    Capybara::Cuprite::Driver.new(app, **cuprite_options)
  end
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

require "active_support/core_ext/integer/time"

Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # Code is not reloaded between requests.
  config.enable_reloading = false

  # Eager load code on boot for better performance and memory savings (ignored by Rake tasks).
  config.eager_load = true

  # Full error reports are disabled.
  config.consider_all_requests_local = false

  # Turn on fragment caching in view templates.
  config.action_controller.perform_caching = true

  # Cache assets for far-future expiry since they are all digest stamped.
  config.public_file_server.headers = { "cache-control" => "public, max-age=#{1.year.to_i}" }

  # Enable serving of images, stylesheets, and JavaScripts from an asset server.
  # config.asset_host = "http://assets.example.com"

  # Store uploaded files on the local file system (see config/storage.yml for options).
  config.active_storage.service = :local

  # Assume all access to the app is happening through a SSL-terminating reverse proxy.
  config.assume_ssl = true

  # Force all access to the app over SSL, use Strict-Transport-Security, and use secure cookies.
  config.force_ssl = true

  # Skip http-to-https redirect for the default health check endpoint.
  # Fly のヘルスチェックが HTTP で /up を叩いても force_ssl のリダイレクトで落ちないようにする。
  config.ssl_options = { redirect: { exclude: ->(request) { request.path == "/up" } } }

  # Log to STDOUT with the current request id as a default log tag.
  config.log_tags = [ :request_id ]
  config.logger   = ActiveSupport::TaggedLogging.logger(STDOUT)

  # Change to "debug" to log everything (including potentially personally-identifiable information!)
  config.log_level = ENV.fetch("RAILS_LOG_LEVEL", "info")

  # Prevent health checks from clogging up the logs.
  config.silence_healthcheck_path = "/up"

  # Don't log any deprecations.
  config.active_support.report_deprecations = false

  # キャッシュは solid_cache（primary DB の solid_cache_entries を使用。rate_limit 等）。
  config.cache_store = :solid_cache_store

  # バックグラウンドジョブは持たない方針（唯一の非同期処理だったリセットメールは deliver_now に変更）。
  # 常駐ワーカーを不要にすることで小さいインスタンスでも OOM せず、scale-to-zero も可能になる。
  # 将来 deliver_later 等が紛れても :inline なら同期実行され、再起動でジョブが消えることはない。
  config.active_job.queue_adapter = :inline

  # メール送信は Resend（SMTP）。Fly.io は SMTP ポート25をブロックするため外部サービスを使う（ADR-0021）。
  # 送信失敗は本番ログに残す。
  config.action_mailer.raise_delivery_errors = true

  # メール本文の【リンク】に使うアプリのホスト（送信元アドレスとは別物）。
  # 送信元（from）は ApplicationMailer の MAIL_FROM で、Resend で検証済みの独自ドメインを指定する。
  # fly.dev は DNS を管理できず送信元ドメインには使えないため、ここ（リンク用）とは分けて設定する。
  config.action_mailer.default_url_options = { host: "kakemieru.fly.dev" }

  # Resend の SMTP 設定。API キーは Fly secrets（RESEND_API_KEY）から取得する。
  config.action_mailer.delivery_method = :smtp
  # deliver_now は送信をリクエストスレッド内で同期実行するため、Resend がハング/遅延すると
  # Puma ワーカーが長時間ブロックされる。open/read timeout を短めに明示して上限を絞る
  # （併せてタイミング列挙で漏れる遅延の最大値も抑える）。
  config.action_mailer.smtp_settings = {
    address: "smtp.resend.com",
    port: 587,
    user_name: "resend",
    password: ENV["RESEND_API_KEY"],
    authentication: :plain,
    enable_starttls_auto: true,
    open_timeout: 5,
    read_timeout: 10
  }

  # Enable locale fallbacks for I18n (makes lookups for any locale fall back to
  # the I18n.default_locale when a translation cannot be found).
  config.i18n.fallbacks = true

  # Do not dump schema after migrations.
  config.active_record.dump_schema_after_migration = false

  # Only use :id for inspections in production.
  config.active_record.attributes_for_inspect = [ :id ]

  # DNS リバインディング/Host ヘッダ攻撃対策。許可ホストを明示する。
  config.hosts = [ "kakemieru.fly.dev" ]
  # ヘルスチェック（/up）はホスト認可から除外する。
  config.host_authorization = { exclude: ->(request) { request.path == "/up" } }
end

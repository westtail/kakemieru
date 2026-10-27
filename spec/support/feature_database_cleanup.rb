# feature spec（Capybara + Cuprite）はアプリサーバが別コンテナの Chrome から
# アクセスされ、テストで作成したデータがコミットされて残留することを実測で確認した
# （掃除前に users/sessions が 1 件ずつ残っていた）。use_transactional_fixtures の
# ロールバックが効かないため、各 feature 例の後にテーブルを truncate して掃除する。
# （model/request spec は従来どおりトランザクションでロールバックされるため対象外）
#
# DatabaseCleaner を導入せず手書きにしているのは、依存を増やさず feature 限定の
# 掃除だけで足りるため（テーブル増加時のメンテは truncate_tables に委譲）。
# 不変条件: スイート全体で共有するデータ（before(:suite) での投入やシード）を作らないこと。
# 実行順はランダムなので、この truncate は model/request の例の合間にも挟まる。共有データを
# 置くと「途中で消える」壊れ方をする。各例が必要なデータを自分で作る前提を崩さないこと。
RSpec.configure do |config|
  config.append_after(:each, type: :feature) do
    conn = ActiveRecord::Base.connection
    tables = conn.tables - %w[schema_migrations ar_internal_metadata]
    conn.truncate_tables(*tables) unless tables.empty?
  end
end

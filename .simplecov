# SimpleCov 設定（spec_helper.rb 冒頭の require "simplecov" で自動ロードされる）
SimpleCov.start "rails" do
  enable_coverage :branch

  # ロジックを持たない自動生成のボイラープレートは計測対象から除外する
  add_filter "/spec/"
  add_filter "/config/"
  add_filter "/db/"
  add_filter "/bin/"
  add_filter "app/channels/application_cable/"
  add_filter "app/jobs/application_job.rb"
  add_filter "app/mailers/application_mailer.rb"
  add_filter "app/models/application_record.rb"
end

# カバレッジ目標（80%）。下回っても失敗させず警告のみ出す（Issue #15 の要件）。
COVERAGE_TARGET = 80

# minimum_coverage を使うと 80% 未満でテストが非ゼロ終了（失敗）になるため使わない。
# 代わりにレポート生成後に自前で判定し、下回った場合のみ警告を表示する。
SimpleCov.at_exit do
  SimpleCov.result.format!
  covered = SimpleCov.result.covered_percent
  if covered < COVERAGE_TARGET
    warn "[SimpleCov] 警告: ライン カバレッジ #{covered.round(2)}% が目標 #{COVERAGE_TARGET}% を下回っています"
  end
end

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

  minimum_coverage 80
end

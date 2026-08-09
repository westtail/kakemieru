# feature spec（実ブラウザ）では、deliver_later のメールを同期配信して内容を検証したい。
# ActiveJob を :inline に切り替え、リクエスト中にメールが ActionMailer::Base.deliveries に入るようにする。
# メールは別スレッド（Puma）のリクエスト処理中に enqueue されるため、テスト側でブロックを囲む
# perform_enqueued_jobs は使いづらい。:inline 切替が適切。
# request spec の have_enqueued_mail（:test アダプタ前提）を壊さないよう feature spec だけで切替、
# 例外時もグローバル状態が残らないよう ensure で必ず復元・後始末する。
RSpec.configure do |config|
  config.around(:each, type: :feature) do |example|
    original_adapter = ActiveJob::Base.queue_adapter
    ActiveJob::Base.queue_adapter = :inline
    ActionMailer::Base.deliveries.clear
    example.run
  ensure
    ActiveJob::Base.queue_adapter = original_adapter
    ActionMailer::Base.deliveries.clear
  end
end

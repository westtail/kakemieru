class DropSolidQueueTables < ActiveRecord::Migration[8.0]
  # solid_queue は不使用（メールは deliver_now・queue_adapter は :inline）のため、
  # 20260806153956 で作成した 11 テーブルを削除する。外部キー(→ solid_queue_jobs)を持つ
  # 実行系テーブルを先に落としてから jobs を落とす。恒久削除のため down は不可逆とする。
  def up
    drop_table :solid_queue_blocked_executions
    drop_table :solid_queue_claimed_executions
    drop_table :solid_queue_failed_executions
    drop_table :solid_queue_ready_executions
    drop_table :solid_queue_recurring_executions
    drop_table :solid_queue_scheduled_executions
    drop_table :solid_queue_jobs
    drop_table :solid_queue_pauses
    drop_table :solid_queue_processes
    drop_table :solid_queue_recurring_tasks
    drop_table :solid_queue_semaphores
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end

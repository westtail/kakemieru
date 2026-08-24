module PaymentMethodsHelper
  # 削除/アーカイブ確認の文言を組み立てる。サーバ側の archivable? 判定に対応させる。
  # - archivable が false: 履歴なし → 物理削除。
  # - active_count > 0: 有効な明細が残っている → その件数を添えてアーカイブを説明。
  # - それ以外（取り消し済み明細のみ / 取り込み履歴のみ）: 件数は出さず履歴ありとして説明。
  # active_count / archivable は一覧で先読みした値を渡す（N+1 回避）。
  def payment_method_removal_confirm(payment_method, active_count:, archivable:)
    name = payment_method.name
    if !archivable
      "「#{name}」を削除します。よろしいですか？"
    elsif active_count.positive?
      "「#{name}」には #{active_count} 件の明細があります。削除せずアーカイブします。よろしいですか？"
    else
      "「#{name}」には履歴があるため、削除せずアーカイブします。よろしいですか？"
    end
  end
end

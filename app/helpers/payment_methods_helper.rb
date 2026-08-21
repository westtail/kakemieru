module PaymentMethodsHelper
  # 削除/アーカイブ確認の文言を組み立てる。サーバ側の archivable? 判定に対応させ、
  # 明細/取り込み履歴があればアーカイブになる旨を N 件付きで説明する。
  # transaction_count / has_import は一覧で先読みした値を渡す（N+1 回避）。
  def payment_method_removal_confirm(payment_method, transaction_count:, has_import:)
    if transaction_count.positive?
      "「#{payment_method.name}」には #{transaction_count} 件の明細があります。" \
        "削除せずアーカイブします。よろしいですか？"
    elsif has_import
      "「#{payment_method.name}」には取り込み履歴があります。" \
        "削除せずアーカイブします。よろしいですか？"
    else
      "「#{payment_method.name}」を削除します。よろしいですか？"
    end
  end
end

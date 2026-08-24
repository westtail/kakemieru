module ImportsHelper
  STATUS_LABELS = { imported: "取込済", partial: "一部取消", canceled: "取消済" }.freeze
  STATUS_CLASSES = { imported: "text-gray-700", partial: "text-orange-700", canceled: "text-gray-500" }.freeze

  # 取り込みの状態。row_count=原本件数, active_count=未削除件数。
  def import_status(row_count, active_count)
    return :canceled if row_count.positive? && active_count.zero?
    return :partial if active_count < row_count

    :imported
  end

  def import_status_label(row_count, active_count)
    STATUS_LABELS.fetch(import_status(row_count, active_count))
  end

  def import_status_class(row_count, active_count)
    STATUS_CLASSES.fetch(import_status(row_count, active_count))
  end

  # source_type の日本語表示名。
  def import_source_label(source_type)
    { "csv" => "CSV取り込み", "manual_bulk" => "手動まとめ入力", "ocr" => "OCR", "api" => "API" }
      .fetch(source_type, source_type)
  end
end

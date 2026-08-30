require "digest"

module Imports
  # アップロードされた楽天カードCSVを取り込み、Import 1件 + Transaction N件を
  # 1トランザクションで保存する。1行でも保存に失敗すれば全ロールバックする。
  # 戻り値: Result(import:, errors:)。errors が空なら成功。
  class CsvImporter
    Result = Struct.new(:import, :errors, keyword_init: true)

    MAX_FILE_SIZE = 5.megabytes
    SOURCE_REF_LIMIT = 255

    def initialize(user:, payment_method:, uploaded_file:)
      @user = user
      @payment_method = payment_method
      @uploaded_file = uploaded_file
    end

    def call
      return failure([ "CSVファイルを選択してください。" ]) if @uploaded_file.blank?

      # read の前にディスク上のサイズで弾く（大容量ファイルをメモリに載せない・DoS 対策）。
      return failure([ oversize_message ]) if @uploaded_file.size.to_i > MAX_FILE_SIZE

      content = @uploaded_file.read.to_s
      return failure([ oversize_message ]) if content.bytesize > MAX_FILE_SIZE # 念のため二層目

      file_hash = Digest::SHA256.hexdigest(content)
      if (existing = @user.imports.find_by(file_hash: file_hash))
        return failure([ "#{existing.created_at.to_date} に同じファイルを取り込み済みです。" ])
      end

      parsed = CsvParser::RakutenCard.parse(content)
      return failure(parsed.errors.presence || [ "取り込める明細がありませんでした。" ]) if parsed.rows.empty?
      # 不正行・行数打ち切りがあればファイル全体を拒否（部分取り込みしない）。ユーザーは直して再取り込み。
      return failure(parsed.errors) if parsed.errors.any?

      save(parsed, file_hash)
    rescue ActiveRecord::RecordNotUnique
      # file_hash の同時送信レース対策（DB の UNIQUE が最後の砦）。
      failure([ "同じファイルは既に取り込み済みです。" ])
    end

    private
      def save(parsed, file_hash)
        errors = []
        # 取込時の自動適用はアカウント設定 ON のときだけ（ADR-0047・初期OFF）。OFF なら未分類で
        # 取り込み、ユーザーが「更新実行」で明示適用する。分類は行ごとだと N+1 になるため一括解決。
        category_ids = if @user.auto_apply_rules_on_import?
          CategoryClassifier.category_ids_for(@user, parsed.rows.map { |row| row[:merchant_name] })
        else
          {}
        end
        import = nil
        ActiveRecord::Base.transaction do
          import = @user.imports.create!(
            payment_method: @payment_method,
            source_type: "csv",
            source_ref: safe_filename,
            file_hash: file_hash,
            row_count: parsed.rows.size,
            imported_at: Time.current
          )
          parsed.rows.each_with_index do |row, index|
            transaction = build_transaction(import, row, category_ids)
            errors << "#{index + 1}件目: #{transaction.errors.full_messages.join('、')}" unless transaction.save
          end
          # 1行でも保存に失敗したら Import ごとロールバック（原子性）。
          raise ActiveRecord::Rollback if errors.any?
        end

        errors.any? ? failure(errors) : Result.new(import: import, errors: [])
      end

      def build_transaction(import, row, category_ids)
        import.transactions.build(
          user: @user,
          payment_method: @payment_method,
          date: row[:date],
          amount: row[:amount],
          description: row[:description],
          merchant_name: row[:merchant_name],
          category_id: category_ids[CategoryClassifier.normalize(row[:merchant_name])]
        )
      end

      # ファイル名は表示・保存のみに使う（パス結合に使わない）。basename 化 + 制御文字除去。
      def safe_filename
        name = File.basename(@uploaded_file.original_filename.to_s).gsub(/[[:cntrl:]]/, "").strip
        name.presence&.slice(0, SOURCE_REF_LIMIT) || "import.csv"
      end

      def oversize_message
        "ファイルサイズが大きすぎます（上限 #{MAX_FILE_SIZE / 1.megabyte}MB）。"
      end

      def failure(errors)
        Result.new(import: nil, errors: errors)
      end
  end
end

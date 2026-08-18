require "securerandom"

module Imports
  # 手動まとめ入力: 複数行の明細を Import(manual_bulk) + Transaction N件として
  # 1トランザクションで保存する。1行でも保存に失敗すれば全ロールバックする。
  # 戻り値: Result(import:, errors:)。errors が空なら成功。CsvImporter と同型。
  class ManualBulkImporter
    Result = Struct.new(:import, :errors, keyword_init: true)

    MAX_ROWS = 50
    ROW_FIELDS = %i[date merchant_name amount category_id payment_method_id].freeze

    def initialize(user:, default_payment_method:, rows:)
      @user = user
      @default_payment_method = default_payment_method
      @rows = Array(rows)
    end

    def call
      entries = present_rows
      return failure([ "明細を1行以上入力してください。" ]) if entries.empty?
      return failure([ "一度に入力できるのは#{MAX_ROWS}件までです。" ]) if entries.size > MAX_ROWS

      save(entries)
    end

    private
      # 全項目が空の行は入力なしとして除外する。
      def present_rows
        @rows.filter_map do |row|
          attrs = row.to_h.symbolize_keys
          next if ROW_FIELDS.all? { |field| attrs[field].to_s.strip.empty? }

          attrs
        end
      end

      def save(entries)
        errors = []
        import = nil
        ActiveRecord::Base.transaction do
          import = @user.imports.create!(
            payment_method: @default_payment_method,
            source_type: "manual_bulk",
            source_ref: nil,
            file_hash: SecureRandom.hex(32), # 手動入力は重複判定しない（毎回一意）
            row_count: entries.size,
            imported_at: Time.current
          )
          entries.each_with_index do |row, index|
            transaction = build_transaction(import, row)
            errors << "#{index + 1}行目: #{transaction.errors.full_messages.join('、')}" unless transaction.save
          end
          # 1行でも失敗したら Import ごとロールバック（原子性）。
          raise ActiveRecord::Rollback if errors.any?
        end

        errors.any? ? failure(errors) : Result.new(import: import, errors: [])
      end

      def build_transaction(import, row)
        # 行ごとの支払方法（未指定はデフォルト）。他ユーザーの category/payment_method は
        # Transaction のテナント整合バリデーションで弾かれる。
        attributes = {
          user: @user,
          date: row[:date].presence,
          amount: row[:amount].presence,
          merchant_name: row[:merchant_name],
          category_id: row[:category_id].presence
        }
        # デフォルト行はオブジェクトを渡してバリデーション時の再ロード（N+1）を避ける。
        if (row_payment_method_id = row[:payment_method_id].presence)
          attributes[:payment_method_id] = row_payment_method_id
        else
          attributes[:payment_method] = @default_payment_method
        end
        import.transactions.build(attributes)
      end

      def failure(errors)
        Result.new(import: nil, errors: errors)
      end
  end
end

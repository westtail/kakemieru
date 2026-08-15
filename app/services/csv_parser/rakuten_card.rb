require "csv"

module CsvParser
  # 楽天カードの利用明細CSV（Shift-JIS）をパースし、Transaction 属性ハッシュの配列を返す。
  # レコードは生成しない（保存は S7）。日付か金額が不正な行はスキップしてエラーに収集する。
  #
  # 使い方: CsvParser::RakutenCard.parse(csv_bytes) #=> Result(rows:, errors:)
  # ActiveSupport に依存しない（素の Ruby / plain ruby でも動く）よう標準ライブラリのみ使用。
  class RakutenCard
    Result = Struct.new(:rows, :errors, keyword_init: true)

    COL_DATE = "利用日"
    COL_DESCRIPTION = "利用店名・商品名"
    COL_AMOUNT = "利用金額"
    # ヘッダー行の判定。必須列がすべて揃っている行だけをヘッダーとみなす。
    # 「利用日」を含むだけのサマリー行を誤検出しないようにする。
    REQUIRED_HEADERS = [ COL_DATE, COL_DESCRIPTION, COL_AMOUNT ].freeze

    MERCHANT_NAME_LIMIT = 255
    # 明細行の上限（DoS 対策の防御的上限。カード明細1ファイルには十分・超過は打ち切る）。
    MAX_ROWS = 10_000

    def self.parse(content)
      new(content).parse
    end

    def initialize(content)
      @content = content
    end

    def parse
      begin
        csv_table = table
      rescue StandardError => e
        # ヘッダー未検出・エンコーディング不正など、ファイル全体の解析失敗。
        return Result.new(rows: [], errors: [ e.message ])
      end

      rows = []
      errors = []
      csv_table.each_with_index do |csv_row, index|
        if rows.size >= MAX_ROWS
          errors << "明細が上限（#{MAX_ROWS}件）を超えたため、以降の行を打ち切りました。"
          break
        end
        attributes = row_to_attributes(csv_row)
        rows << attributes if attributes
      rescue StandardError => e
        errors << "#{index + 1}行目: #{e.message}"
      end
      Result.new(rows: rows, errors: errors)
    end

    private

    # Shift-JIS を UTF-8 に変換し、「利用日」を含むヘッダー行以降だけを CSV としてパースする。
    # 先頭に口座サマリー行が入る場合があるためヘッダーを自動検出する。
    def table
      utf8 = @content.to_s.dup.force_encoding("Shift_JIS").encode("UTF-8", invalid: :replace, undef: :replace)
      lines = utf8.lines
      header_index = lines.index { |line| REQUIRED_HEADERS.all? { |header| line.include?(header) } }
      raise "ヘッダー行（#{REQUIRED_HEADERS.join('/')}）が見つかりません" if header_index.nil?

      CSV.parse(lines[header_index..].join, headers: true)
    end

    def row_to_attributes(csv_row)
      date = csv_row[COL_DATE].to_s.strip
      amount = csv_row[COL_AMOUNT].to_s.strip
      description = csv_row[COL_DESCRIPTION].to_s.strip
      # 空行・合計行など、日付か金額が無い行はスキップ（エラーにはしない）。
      return nil if date.empty? || amount.empty?

      {
        date: parse_date(date),
        amount: parse_amount(amount),
        description: description,
        merchant_name: normalize_merchant(description)
      }
    end

    # 楽天CSVの利用日は YYYY/MM/DD 固定。strptime で厳密に解釈し、フォーマット逸脱は
    # 例外にして per-row エラーへ回す（Date.parse は曖昧入力を推測解釈するため使わない）。
    def parse_date(text)
      Date.strptime(text, "%Y/%m/%d")
    end

    # 金額はカンマ除去後に符号付き整数として厳密に検証する。to_i は不正値を無音で 0 や
    # 部分値に変換してしまい、家計簿の金額整合性を壊すため使わない。
    def parse_amount(text)
      digits = text.delete(",")
      raise "利用金額が不正です: #{text.inspect}" unless /\A-?\d+\z/.match?(digits)

      Integer(digits, 10)
    end

    # 摘要を店舗名キーに正規化（NFKC で全角→半角・前後空白除去・上限文字数）。
    def normalize_merchant(text)
      normalized = text.to_s.unicode_normalize(:nfkc).strip
      return nil if normalized.empty?

      normalized[0, MERCHANT_NAME_LIMIT]
    end
  end
end

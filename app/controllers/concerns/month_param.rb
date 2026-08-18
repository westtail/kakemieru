# `?month=YYYY-MM` の共通パース。厳密に YYYY-MM のみ許可し、不正・欠落・非文字列は nil を返す
# （strptime は末尾ゴミ "2026-04xx" を無視して通すため、正規表現で先に固定する）。
module MonthParam
  extend ActiveSupport::Concern

  private
    def parse_month(value)
      return nil unless value.is_a?(String) && value.match?(/\A\d{4}-\d{2}\z/)

      Date.strptime(value, "%Y-%m")
    rescue ArgumentError
      nil
    end
end

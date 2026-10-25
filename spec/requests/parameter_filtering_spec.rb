require "rails_helper"

# 家計データが本番ログに平文で残らないことを守るガード（#196）。
#
# Rails は INFO レベルでリクエストパラメータを出力するため、filter_parameters から項目が
# 漏れると、手動入力・明細編集・検索キーワードがそのまま Fly.io のログに蓄積される。
# 一度書かれると DB と違って後から消すのが難しいので、設定自体をここで検証する。
RSpec.describe "ログのパラメータフィルタ" do
  let(:filter) { ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters) }

  def filtered(params)
    filter.filter(params.deep_stringify_keys)
  end

  describe "家計データは伏せる" do
    it "明細の店舗名・訂正金額・説明" do
      result = filtered(transaction: { merchant_name: "スターバックス渋谷店",
                                       amount_override: "1480",
                                       description: "打ち合わせ" })

      aggregate_failures do
        expect(result["transaction"]["merchant_name"]).to eq("[FILTERED]")
        expect(result["transaction"]["amount_override"]).to eq("[FILTERED]")
        expect(result["transaction"]["description"]).to eq("[FILTERED]")
      end
    end

    it "手動まとめ入力（ネストした配列の中身まで）" do
      result = filtered(manual: { transactions: [ { merchant_name: "薬局A", amount: "3200" } ] })

      row = result["manual"]["transactions"].first
      aggregate_failures do
        expect(row["merchant_name"]).to eq("[FILTERED]")
        expect(row["amount"]).to eq("[FILTERED]")
      end
    end

    it "特別ルールの金額条件とメモ" do
      result = filtered(special_rule: { merchant_name: "家賃", amount_min: "80000",
                                        amount_max: "90000", note: "毎月の家賃" })

      aggregate_failures do
        expect(result["special_rule"]["merchant_name"]).to eq("[FILTERED]")
        expect(result["special_rule"]["amount_min"]).to eq("[FILTERED]")
        expect(result["special_rule"]["amount_max"]).to eq("[FILTERED]")
        expect(result["special_rule"]["note"]).to eq("[FILTERED]")
      end
    end

    it "検索キーワード（「病院」など意図が推測できる語）" do
      expect(filtered(q: "病院")["q"]).to eq("[FILTERED]")
    end

    it "カテゴリ名・支払方法名（支出構造や保有カードが分かる）" do
      aggregate_failures do
        expect(filtered(category: { name: "医療費" })["category"]["name"]).to eq("[FILTERED]")
        expect(filtered(payment_method: { name: "楽天カード" })["payment_method"]["name"]).to eq("[FILTERED]")
      end
    end

    it "認証情報（既存の設定）" do
      result = filtered(user: { email_address: "a@example.com", password: "x" }, current_password: "y")

      aggregate_failures do
        expect(result["user"]["email_address"]).to eq("[FILTERED]")
        expect(result["user"]["password"]).to eq("[FILTERED]")
        expect(result["current_password"]).to eq("[FILTERED]")
      end
    end
  end

  describe "障害調査に要る値は残す" do
    it "日付・種別・並び順・対象月" do
      result = filtered(transaction: { date: "2026-10-25" }, payment_method: { payment_type: "credit" },
                        sort: "amount", direction: "desc", month: "2026-10")

      aggregate_failures do
        expect(result["transaction"]["date"]).to eq("2026-10-25")
        expect(result["payment_method"]["payment_type"]).to eq("credit")
        expect(result["sort"]).to eq("amount")       # キーが sort なので値が amount でも残る
        expect(result["direction"]).to eq("desc")
        expect(result["month"]).to eq("2026-10")
      end
    end
  end
end

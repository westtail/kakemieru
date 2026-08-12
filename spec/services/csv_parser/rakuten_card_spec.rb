require "rails_helper"

RSpec.describe CsvParser::RakutenCard do
  # 楽天カードCSV（Shift-JIS）を模したデータ。先頭サマリー行・ヘッダー・明細・空行・不正日付行を含む。
  let(:csv) do
    <<~CSV.encode("Shift_JIS")
      ご利用明細,,,,,,
      利用日,利用店名・商品名,利用者,支払方法,利用金額,支払手数料,支払総額
      2026/01/15,ローソン渋谷店,本人,1回払い,"1,200",0,"1,200"
      2026/01/20,Ａｍａｚｏｎ.co.jp,家族,1回払い,3500,0,3500
      ,,,,,,
      不正日付,店,本人,1回払い,500,0,500
    CSV
  end

  subject(:result) { described_class.parse(csv) }

  it "明細行のみを Transaction 属性ハッシュ配列に変換する（サマリー・空行・不正行は除外）" do
    expect(result.rows.size).to eq(2)
  end

  it "先頭のサマリー行をスキップしてヘッダーを自動検出する" do
    expect(result.rows.first[:description]).to eq("ローソン渋谷店")
  end

  it "利用日を Date に変換する" do
    expect(result.rows.first[:date]).to eq(Date.new(2026, 1, 15))
  end

  it "利用金額のカンマを除去して整数にする" do
    expect(result.rows.first[:amount]).to eq(1200)
  end

  it "merchant_name を正規化する（全角英数→半角・NFKC）" do
    expect(result.rows[1][:merchant_name]).to eq("Amazon.co.jp")
  end

  it "日付か金額が空の行はスキップする（エラーにしない）" do
    expect(result.rows.map { |r| r[:description] }).not_to include("")
  end

  it "日付が不正な行はスキップしてエラーに収集する" do
    expect(result.errors.size).to eq(1)
    expect(result.errors.first).to include("行目")
  end

  it "ヘッダー行が無ければエラーを1件返す" do
    result = described_class.parse("summary,only\n1,2".encode("Shift_JIS"))
    expect(result.rows).to be_empty
    expect(result.errors).not_to be_empty
  end

  it "「利用日」を含むサマリー行があっても、必須列が揃った本ヘッダーを検出する" do
    csv = <<~CSV.encode("Shift_JIS")
      利用日: 2026/01/01 〜 2026/01/31,,,,,,
      利用日,利用店名・商品名,利用者,支払方法,利用金額,支払手数料,支払総額
      2026/01/15,ローソン,本人,1回払い,300,0,300
    CSV
    result = described_class.parse(csv)
    expect(result.rows.size).to eq(1)
    expect(result.rows.first[:amount]).to eq(300)
  end

  it "利用金額が数値でない行はスキップしてエラーに収集する（金額整合性）" do
    csv = <<~CSV.encode("Shift_JIS")
      利用日,利用店名・商品名,利用者,支払方法,利用金額,支払手数料,支払総額
      2026/02/01,店,本人,1回払い,1200yen,0,0
    CSV
    result = described_class.parse(csv)
    expect(result.rows).to be_empty
    expect(result.errors.size).to eq(1)
  end
end

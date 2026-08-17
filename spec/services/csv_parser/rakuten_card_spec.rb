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

  it "明細が行数上限を超えたら打ち切り、エラーに記録する（DoS 防御）" do
    stub_const("CsvParser::RakutenCard::MAX_ROWS", 2)
    csv = <<~CSV.encode("Shift_JIS")
      利用日,利用店名・商品名,利用者,支払方法,利用金額,支払手数料,支払総額
      2026/01/01,A,本人,1回払い,100,0,100
      2026/01/02,B,本人,1回払い,200,0,200
      2026/01/03,C,本人,1回払い,300,0,300
    CSV
    result = described_class.parse(csv)
    expect(result.rows.size).to eq(2)
    expect(result.errors.join).to include("上限")
  end

  it "上限ちょうどの有効行の後に空行/集計行があっても打ち切りエラーにしない" do
    stub_const("CsvParser::RakutenCard::MAX_ROWS", 2)
    csv = <<~CSV.encode("Shift_JIS")
      利用日,利用店名・商品名,利用者,支払方法,利用金額,支払手数料,支払総額
      2026/01/01,A,本人,1回払い,100,0,100
      2026/01/02,B,本人,1回払い,200,0,200
      ,,,,,,
    CSV
    result = described_class.parse(csv)
    expect(result.rows.size).to eq(2)
    expect(result.errors).to be_empty
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

  describe "エンコーディングの柔軟性（Shift-JIS / UTF-8）" do
    # Excel で開いて保存したり UTF-8 でダウンロードした CSV も取り込めるようにする。
    let(:utf8_csv) do
      <<~CSV
        利用日,利用店名・商品名,利用者,支払方法,利用金額,支払手数料,支払総額
        2026/03/10,UTF8ストア,本人,1回払い,"2,000",0,"2,000"
      CSV
    end

    it "UTF-8 の CSV を取り込める" do
      result = described_class.parse(utf8_csv)
      expect(result.errors).to be_empty
      expect(result.rows.size).to eq(1)
      expect(result.rows.first[:amount]).to eq(2000)
      expect(result.rows.first[:merchant_name]).to eq("UTF8ストア")
    end

    it "UTF-8 BOM 付きの CSV を取り込める" do
      result = described_class.parse("﻿" + utf8_csv)
      expect(result.errors).to be_empty
      expect(result.rows.size).to eq(1)
    end

    it "UTF-8（BOM付き）で先頭にサマリー行があってもヘッダーを自動検出して取り込める" do
      csv = "﻿" + <<~CSV
        ご利用明細,,,,,,
        利用日,利用店名・商品名,利用者,支払方法,利用金額,支払手数料,支払総額
        2026/03/10,前置きストア,本人,1回払い,1500,0,1500
      CSV
      result = described_class.parse(csv)
      expect(result.errors).to be_empty
      expect(result.rows.size).to eq(1)
      expect(result.rows.first[:merchant_name]).to eq("前置きストア")
    end

    it "全項目クォート付き・列数の多い実フォーマット（UTF-8）でも取り込める" do
      csv = <<~CSV
        "利用日","利用店名・商品名","利用者","支払方法","利用金額","手数料/利息","支払総額","4月支払金額","5月繰越残高","新規サイン"
        "2026/04/15","ローソン","本人","1回払い","1,200","0","1,200","1,200","0",""
      CSV
      result = described_class.parse(csv)
      expect(result.errors).to be_empty
      expect(result.rows.size).to eq(1)
      expect(result.rows.first[:amount]).to eq(1200)
      expect(result.rows.first[:merchant_name]).to eq("ローソン")
    end
  end
end

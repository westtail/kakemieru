require "rails_helper"

RSpec.describe Imports::CsvImporter do
  let(:user) { create(:user) }
  let(:payment_method) { create(:payment_method, user: user) }

  def uploaded(text, filename: "rakuten.csv")
    Rack::Test::UploadedFile.new(StringIO.new(text.encode("Shift_JIS")), "text/csv", original_filename: filename)
  end

  def import(text, filename: "rakuten.csv")
    described_class.new(user: user, payment_method: payment_method, uploaded_file: uploaded(text, filename: filename)).call
  end

  let(:valid_csv) do
    <<~CSV
      利用日,利用店名・商品名,利用者,支払方法,利用金額,支払手数料,支払総額
      2026/01/15,ローソン,本人,1回払い,"1,200",0,"1,200"
      2026/01/20,Amazon,本人,1回払い,3500,0,3500
    CSV
  end

  it "正常なCSVで Import + Transaction を作成する" do
    result = import(valid_csv)

    expect(result.errors).to be_empty
    expect(result.import).to be_persisted
    expect(result.import.source_type).to eq("csv")
    expect(result.import.row_count).to eq(2)
    expect(user.transactions.count).to eq(2)
    expect(user.transactions.pluck(:import_id).uniq).to eq([ result.import.id ])
    expect(user.transactions.pluck(:category_id).uniq).to eq([ nil ]) # merchant_classifications 空 = 未分類
  end

  it "店舗ルール登録済みの店舗は取込時に自動分類される（ADR-0047 end-to-end）" do
    food = create(:category, user: user, name: "食費")
    # 店舗ルール（ローソン → 食費）を登録しておく。
    create(:merchant_classification, user: user, category: food, merchant_name: "ローソン")

    result = import(valid_csv)

    lawson = user.transactions.find_by(merchant_name: "ローソン")
    amazon = user.transactions.find_by(merchant_name: "Amazon")
    expect(lawson.category_id).to eq(food.id) # 学習済み → 自動分類
    expect(amazon.category_id).to be_nil      # 未学習 → 未分類
  end

  it "ファイル名は basename 化して source_ref に保存する" do
    result = import(valid_csv, filename: "../../etc/passwd.csv")
    expect(result.import.source_ref).to eq("passwd.csv")
  end

  it "同じ内容のファイルは重複として拒否し、明細を増やさない" do
    import(valid_csv)
    result = import(valid_csv)

    expect(result.import).to be_nil
    expect(result.errors.join).to include("取り込み済み")
    expect(user.transactions.count).to eq(2)
  end

  it "ヘッダーの無い不正CSVはエラーを返し何も作らない" do
    result = import("ゴミ,データ\n1,2")

    expect(result.import).to be_nil
    expect(result.errors).not_to be_empty
    expect(user.imports.count).to eq(0)
  end

  it "不正フォーマットの行が混じるCSVはファイル全体を拒否する（部分取り込みしない）" do
    dirty = <<~CSV
      利用日,利用店名・商品名,利用者,支払方法,利用金額,支払手数料,支払総額
      2026/01/15,ローソン,本人,1回払い,1200,0,1200
      不正日付,ダメ,本人,1回払い,500,0,500
    CSV
    result = import(dirty)

    expect(result.import).to be_nil
    expect(result.errors).not_to be_empty
    expect(user.imports.count).to eq(0)
    expect(user.transactions.count).to eq(0)
  end

  it "ファイルサイズ超過は拒否する" do
    result = import("x" * (described_class::MAX_FILE_SIZE + 1))
    expect(result.import).to be_nil
    expect(result.errors.join).to include("大きすぎ")
  end

  it "ファイル未選択はエラー" do
    result = described_class.new(user: user, payment_method: payment_method, uploaded_file: nil).call
    expect(result.errors).not_to be_empty
  end

  it "1行でも保存に失敗すれば全ロールバック（Import も明細も残らない）" do
    bad = <<~CSV
      利用日,利用店名・商品名,利用者,支払方法,利用金額,支払手数料,支払総額
      2026/01/15,ローソン,本人,1回払い,1200,0,1200
      2026/01/16, ,本人,1回払い,500,0,500
    CSV
    result = import(bad)

    expect(result.import).to be_nil
    expect(result.errors).not_to be_empty
    expect(user.imports.count).to eq(0)
    expect(user.transactions.count).to eq(0)
  end
end

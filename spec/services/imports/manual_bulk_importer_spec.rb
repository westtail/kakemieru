require "rails_helper"

RSpec.describe Imports::ManualBulkImporter do
  let(:user) { create(:user) }
  let(:default_pm) { create(:payment_method, user: user, name: "現金", payment_type: "cash") }

  def run(rows, default: default_pm)
    described_class.new(user: user, default_payment_method: default, rows: rows).call
  end

  def row(overrides = {})
    { date: "2026-01-15", merchant_name: "ローソン", amount: "1200",
      category_id: nil, payment_method_id: nil }.merge(overrides)
  end

  it "複数行を Import(manual_bulk) + Transaction として保存する" do
    result = run([ row, row(merchant_name: "自販機", amount: "150") ])

    expect(result.errors).to be_empty
    expect(result.import.source_type).to eq("manual_bulk")
    expect(result.import.source_ref).to be_nil
    expect(result.import.row_count).to eq(2)
    expect(user.transactions.count).to eq(2)
    expect(user.transactions.pluck(:import_id).uniq).to eq([ result.import.id ])
    # 支払方法未指定はデフォルト、import_id は付く
    expect(user.transactions.pluck(:payment_method_id).uniq).to eq([ default_pm.id ])
  end

  it "全項目空の行はスキップする" do
    result = run([ row, { date: "", merchant_name: "", amount: "", category_id: "", payment_method_id: "" } ])
    expect(result.errors).to be_empty
    expect(result.import.row_count).to eq(1)
    expect(user.transactions.count).to eq(1)
  end

  it "実入力が0行ならエラー" do
    result = run([ { date: "", merchant_name: "", amount: "" } ])
    expect(result.import).to be_nil
    expect(result.errors).not_to be_empty
    expect(user.imports.count).to eq(0)
  end

  it "50件を超えるとエラー" do
    result = run(Array.new(51) { row })
    expect(result.import).to be_nil
    expect(result.errors.join).to include("50")
  end

  it "1行でも不正なら全ロールバック（Import も明細も残らない）" do
    result = run([ row, row(amount: "") ]) # 金額空 → presence 違反

    expect(result.import).to be_nil
    expect(result.errors).not_to be_empty
    expect(user.imports.count).to eq(0)
    expect(user.transactions.count).to eq(0)
  end

  it "行ごとに支払方法を指定でき、カテゴリも紐づく" do
    card = create(:payment_method, user: user, name: "楽天カード")
    food = create(:category, user: user, category_key: "food", name: "食費")

    result = run([ row(payment_method_id: card.id, category_id: food.id) ])

    tx = user.transactions.last
    expect(tx.payment_method_id).to eq(card.id)
    expect(tx.category_id).to eq(food.id)
    expect(result.errors).to be_empty
  end

  it "他ユーザーの支払方法/カテゴリは拒否してロールバック" do
    other = create(:user)
    others_pm = create(:payment_method, user: other)
    result = run([ row(payment_method_id: others_pm.id) ])

    expect(result.import).to be_nil
    expect(user.imports.count).to eq(0)
  end

  it "file_hash は毎回一意で、同じ内容でも重複保存できる" do
    run([ row ])
    result = run([ row ])
    expect(result.errors).to be_empty
    expect(user.imports.count).to eq(2)
  end
end

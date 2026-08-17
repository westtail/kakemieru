require "rails_helper"

RSpec.describe Transactions::MonthlySummary do
  let(:user) { create(:user) }
  let(:payment_method) { create(:payment_method, user: user) }
  let(:food) { create(:category, user: user, name: "食費") }
  let(:transport) { create(:category, user: user, name: "交通費") }

  def tx(amount:, category: nil, date: Date.new(2026, 4, 10), **overrides)
    create(:transaction, user: user, payment_method: payment_method,
           amount: amount, category: category, date: date, **overrides)
  end

  subject(:summary) { described_class.new(user: user, month: Date.new(2026, 4, 1)).call }

  it "月・合計・カテゴリ別（amount 降順）を返す" do
    tx(amount: 3000, category: food)
    tx(amount: 5000, category: food)
    tx(amount: 2000, category: transport)
    tx(amount: 1000, category: nil) # 未分類

    expect(summary[:month]).to eq("2026-04")
    expect(summary[:total]).to eq(11_000)
    expect(summary[:categories]).to eq([
      { id: food.id, name: "食費", amount: 8000 },
      { id: transport.id, name: "交通費", amount: 2000 },
      { id: nil, name: "未分類", amount: 1000 }
    ])
  end

  it "返金（マイナス）を含む符号付き合計になる" do
    tx(amount: 5000, category: food)
    tx(amount: -2000, category: food) # 返金
    expect(summary[:total]).to eq(3000)
    expect(summary[:categories].first).to eq({ id: food.id, name: "食費", amount: 3000 })
  end

  it "対象月・本人・未削除のみを集計する" do
    tx(amount: 5000, category: food)                         # 対象
    tx(amount: 9999, category: food, date: Date.new(2026, 3, 10)) # 別月
    tx(amount: 8888, category: food, deleted_at: Time.current)    # 削除済み
    other = create(:user)
    create(:transaction, user: other, payment_method: create(:payment_method, user: other),
           amount: 7777, date: Date.new(2026, 4, 10))              # 他ユーザー

    expect(summary[:total]).to eq(5000)
  end

  it "明細が無い月は total 0・categories 空" do
    expect(summary).to eq(month: "2026-04", total: 0, categories: [])
  end
end

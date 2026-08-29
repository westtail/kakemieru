require "rails_helper"

RSpec.describe Transactions::MonthlyTotals do
  let(:user) { create(:user) }
  let(:pm) { create(:payment_method, user: user) }

  def tx(date, amount, **opts)
    create(:transaction, user: user, payment_method: pm, date: date, amount: amount, **opts)
  end

  it "指定月を末尾に直近 count ヶ月の合計を古い順で返す" do
    tx(Date.new(2026, 3, 10), 1000)
    tx(Date.new(2026, 3, 20), 500)  # 3月合計 1500
    tx(Date.new(2026, 1, 5), 800)   # 1月合計 800

    result = described_class.new(user: user, month: Date.new(2026, 3, 1), count: 3).call

    expect(result).to eq([
      { month: "2026-01", total: 800 },
      { month: "2026-02", total: 0 },   # データ無し → 0 で埋める
      { month: "2026-03", total: 1500 }
    ])
  end

  it "effective_amount（訂正後）で集計し、取り消し済みは除外する" do
    tx(Date.new(2026, 3, 5), 1000, amount_override: 300) # effective 300
    deleted = tx(Date.new(2026, 3, 6), 999)
    deleted.soft_delete!

    result = described_class.new(user: user, month: Date.new(2026, 3, 1), count: 1).call
    expect(result).to eq([ { month: "2026-03", total: 300 } ])
  end

  it "他ユーザーの明細は含めない" do
    other = create(:user)
    create(:transaction, user: other, payment_method: create(:payment_method, user: other),
           date: Date.new(2026, 3, 10), amount: 5000)
    tx(Date.new(2026, 3, 10), 100)

    result = described_class.new(user: user, month: Date.new(2026, 3, 1), count: 1).call
    expect(result).to eq([ { month: "2026-03", total: 100 } ])
  end

  it "既定は直近6ヶ月" do
    result = described_class.new(user: user, month: Date.new(2026, 6, 1)).call
    expect(result.map { |r| r[:month] }).to eq(%w[2026-01 2026-02 2026-03 2026-04 2026-05 2026-06])
    expect(result.map { |r| r[:total] }).to all(eq(0))
  end
end

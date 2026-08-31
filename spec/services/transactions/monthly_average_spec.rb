require "rails_helper"

module Transactions
  RSpec.describe MonthlyAverage, type: :service do
    let(:user) { create(:user) }
    let(:payment_method) { create(:payment_method, user: user) }
    let(:food) { create(:category, user: user, name: "食費") }
    let(:transport) { create(:category, user: user, name: "交通費") }

    def tx(amount:, date:, category: nil)
      create(:transaction, user: user, payment_method: payment_method, amount: amount, date: date, category: category)
    end

    def call
      described_class.new(user: user).call
    end

    it "実データのある月数で全体・カテゴリ別の月平均を返す" do
      # 2 ヶ月分（2026-03, 2026-04）にデータ。分母 = 2。
      tx(amount: 3000, date: Date.new(2026, 3, 10), category: food)
      tx(amount: 5000, date: Date.new(2026, 4, 10), category: food)
      tx(amount: 2000, date: Date.new(2026, 4, 12), category: transport)

      result = call
      expect(result[:months]).to eq(2)
      expect(result[:overall]).to eq(5000) # (3000+5000+2000)/2
      expect(result[:categories]).to eq([
        { id: food.id, name: "食費", average: 4000 },      # 8000/2
        { id: transport.id, name: "交通費", average: 1000 } # 2000/2
      ])
    end

    it "空の月（明細ゼロ）は分母に含めない" do
      # 同一月に2件でも分母は1ヶ月。
      tx(amount: 1000, date: Date.new(2026, 4, 1), category: food)
      tx(amount: 3000, date: Date.new(2026, 4, 20), category: food)

      result = call
      expect(result[:months]).to eq(1)
      expect(result[:overall]).to eq(4000)
    end

    it "未分類も1カテゴリとして含める" do
      tx(amount: 1200, date: Date.new(2026, 4, 10), category: nil)
      expect(call[:categories]).to eq([ { id: nil, name: "未分類", average: 1200 } ])
    end

    it "データが無ければ months=0・overall=0・categories 空" do
      expect(call).to eq({ months: 0, overall: 0, categories: [] })
    end

    it "取り消し済み（ソフトデリート）は集計しない" do
      tx(amount: 5000, date: Date.new(2026, 4, 10), category: food).soft_delete!
      expect(call).to eq({ months: 0, overall: 0, categories: [] })
    end

    it "他ユーザーの明細は混ざらない（テナント）" do
      other = create(:user)
      other_pm = create(:payment_method, user: other)
      create(:transaction, user: other, payment_method: other_pm, amount: 9999, date: Date.new(2026, 4, 10))
      tx(amount: 1000, date: Date.new(2026, 4, 10), category: food)

      expect(call[:overall]).to eq(1000)
    end

    it "平均は四捨五入した整数（円）で返す（端数はカテゴリ別・全体で独立に丸める）" do
      # 3 ヶ月・食費計 1000・交通費計 1000。各カテゴリ 1000/3=333.33→333、全体 2000/3=666.67→667。
      tx(amount: 400, date: Date.new(2026, 3, 10), category: food)
      tx(amount: 300, date: Date.new(2026, 4, 10), category: food)
      tx(amount: 500, date: Date.new(2026, 4, 12), category: transport)
      tx(amount: 300, date: Date.new(2026, 5, 10), category: food)
      tx(amount: 500, date: Date.new(2026, 5, 12), category: transport)

      result = call
      expect(result[:months]).to eq(3)
      expect(result[:overall]).to eq(667) # 666.67 の四捨五入
      # 同額(333)は名前昇順のタイブレーク（交通費 < 食費）。
      expect(result[:categories]).to eq([
        { id: transport.id, name: "交通費", average: 333 },
        { id: food.id, name: "食費", average: 333 }
      ])
      # 独立丸めのためカテゴリ別合計(666)と全体(667)は一致しない（仕様）。
      expect(result[:categories].sum { |c| c[:average] }).not_to eq(result[:overall])
    end
  end
end

require "rails_helper"

module Transactions
  RSpec.describe RecentAverageComparison, type: :service do
    let(:user) { create(:user) }
    let(:payment_method) { create(:payment_method, user: user) }
    let(:month) { Date.new(2026, 4, 1) }

    def tx(amount:, date:)
      create(:transaction, user: user, payment_method: payment_method, amount: amount, date: date)
    end

    def call(current_total:)
      described_class.new(user: user, month: month, current_total: current_total).call
    end

    it "直前3ヶ月の平均・差額・増減率を返す（当月 > 平均）" do
      tx(amount: 3000, date: Date.new(2026, 1, 10))
      tx(amount: 5000, date: Date.new(2026, 2, 10))
      tx(amount: 4000, date: Date.new(2026, 3, 10))

      result = call(current_total: 6000)
      expect(result[:window]).to eq(3)
      expect(result[:months]).to eq(3)        # データのある月数
      expect(result[:baseline]).to eq(4000)   # (3000+5000+4000)/3
      expect(result[:diff]).to eq(2000)       # 6000 - 4000
      expect(result[:rate]).to eq(50.0)       # +50%
    end

    it "当月の明細は基準（直近3ヶ月）に含めない" do
      tx(amount: 4000, date: Date.new(2026, 3, 10))
      tx(amount: 9999, date: Date.new(2026, 4, 20)) # 当月＝基準に入れない

      result = call(current_total: 6000)
      expect(result[:months]).to eq(1)
      expect(result[:baseline]).to eq(4000)
    end

    it "基準は『データのある月数』で割る（空の月は分母に含めない）" do
      # 2月のみデータ（1月・3月は空）→ 分母 1。
      tx(amount: 3000, date: Date.new(2026, 2, 10))

      result = call(current_total: 5000)
      expect(result[:months]).to eq(1)
      expect(result[:baseline]).to eq(3000)
      expect(result[:diff]).to eq(2000)
    end

    it "3ヶ月とも4ヶ月以上前より外のデータは含めない（範囲）" do
      tx(amount: 9999, date: Date.new(2025, 12, 31)) # 直前3ヶ月(1〜3月)より前
      result = call(current_total: 5000)
      expect(result[:months]).to eq(0)
      expect(result[:baseline]).to eq(0)
      expect(result[:rate]).to be_nil
    end

    it "直近3ヶ月にデータが無ければ率は nil（差額は当月そのもの）" do
      result = call(current_total: 3000)
      expect(result[:months]).to eq(0)
      expect(result[:baseline]).to eq(0)
      expect(result[:diff]).to eq(3000)
      expect(result[:rate]).to be_nil
    end

    it "率は小数第1位に丸める" do
      tx(amount: 3000, date: Date.new(2026, 3, 10))
      expect(call(current_total: 1000)[:rate]).to eq(-66.7) # (1000-3000)/3000
    end

    it "取り消し済み（ソフトデリート）は基準に含めない" do
      tx(amount: 5000, date: Date.new(2026, 3, 10)).soft_delete!
      result = call(current_total: 6000)
      expect(result[:months]).to eq(0)
      expect(result[:rate]).to be_nil
    end

    it "他ユーザーの明細は混ざらない（テナント）" do
      other = create(:user)
      other_pm = create(:payment_method, user: other)
      create(:transaction, user: other, payment_method: other_pm, amount: 9999, date: Date.new(2026, 3, 10))
      expect(call(current_total: 6000)[:months]).to eq(0)
    end
  end
end

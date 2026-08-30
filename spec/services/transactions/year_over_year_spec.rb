require "rails_helper"

module Transactions
  RSpec.describe YearOverYear, type: :service do
    let(:user) { create(:user) }
    let(:payment_method) { create(:payment_method, user: user) }

    def tx(amount:, date:)
      create(:transaction, user: user, payment_method: payment_method, amount: amount, date: date)
    end

    def call(month = Date.new(2026, 4, 1))
      described_class.new(user: user, month: month).call
    end

    it "前年同月の合計・差額・増減率を返す（当月 > 前年）" do
      tx(amount: 6000, date: Date.new(2026, 4, 10)) # 当月
      tx(amount: 5000, date: Date.new(2025, 4, 10)) # 前年同月

      result = call
      expect(result[:previous_month]).to eq("2025-04")
      expect(result[:previous_total]).to eq(5000)
      expect(result[:diff]).to eq(1000)        # 6000 - 5000
      expect(result[:rate]).to eq(20.0)        # +20%
    end

    it "当月 < 前年ならマイナスの差額・率" do
      tx(amount: 4000, date: Date.new(2026, 4, 10))
      tx(amount: 5000, date: Date.new(2025, 4, 10))

      result = call
      expect(result[:diff]).to eq(-1000)
      expect(result[:rate]).to eq(-20.0)
    end

    it "前年同月にデータが無ければ率は nil（差額は当月そのもの）" do
      tx(amount: 3000, date: Date.new(2026, 4, 10))

      result = call
      expect(result[:previous_total]).to eq(0)
      expect(result[:diff]).to eq(3000)
      expect(result[:rate]).to be_nil
    end

    it "率は小数第1位に丸める" do
      tx(amount: 1000, date: Date.new(2026, 4, 10))
      tx(amount: 3000, date: Date.new(2025, 4, 10))

      expect(call[:rate]).to eq(-66.7) # (1000-3000)/3000 = -66.66..%
    end

    it "取り消し済み（ソフトデリート）は集計しない" do
      tx(amount: 6000, date: Date.new(2026, 4, 10))
      tx(amount: 5000, date: Date.new(2025, 4, 10)).soft_delete!

      result = call
      expect(result[:previous_total]).to eq(0)
      expect(result[:rate]).to be_nil
    end

    it "他ユーザーの明細は混ざらない（テナント）" do
      other = create(:user)
      other_pm = create(:payment_method, user: other)
      create(:transaction, user: other, payment_method: other_pm, amount: 9999, date: Date.new(2025, 4, 10))
      tx(amount: 6000, date: Date.new(2026, 4, 10))

      expect(call[:previous_total]).to eq(0)
    end
  end
end

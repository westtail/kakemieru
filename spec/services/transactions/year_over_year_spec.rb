require "rails_helper"

module Transactions
  RSpec.describe YearOverYear, type: :service do
    let(:user) { create(:user) }
    let(:payment_method) { create(:payment_method, user: user) }
    let(:month) { Date.new(2026, 4, 1) }

    def prev_year_tx(amount:)
      create(:transaction, user: user, payment_method: payment_method, amount: amount, date: Date.new(2025, 4, 10))
    end

    def call(current_total:)
      described_class.new(user: user, month: month, current_total: current_total).call
    end

    it "前年同月の合計・差額・増減率を返す（当月 > 前年）" do
      prev_year_tx(amount: 5000)

      result = call(current_total: 6000)
      expect(result[:previous_month]).to eq("2025-04")
      expect(result[:previous_total]).to eq(5000)
      expect(result[:diff]).to eq(1000)   # 6000 - 5000
      expect(result[:rate]).to eq(20.0)   # +20%
    end

    it "当月 < 前年ならマイナスの差額・率" do
      prev_year_tx(amount: 5000)

      result = call(current_total: 4000)
      expect(result[:diff]).to eq(-1000)
      expect(result[:rate]).to eq(-20.0)
    end

    it "前年同月にデータが無ければ率は nil（差額は当月そのもの）" do
      result = call(current_total: 3000)
      expect(result[:previous_total]).to eq(0)
      expect(result[:diff]).to eq(3000)
      expect(result[:rate]).to be_nil
    end

    it "率は小数第1位に丸める" do
      prev_year_tx(amount: 3000)
      expect(call(current_total: 1000)[:rate]).to eq(-66.7) # (1000-3000)/3000 = -66.66..%
    end

    it "取り消し済み（ソフトデリート）は前年同月の集計から除外する" do
      prev_year_tx(amount: 5000).soft_delete!

      result = call(current_total: 6000)
      expect(result[:previous_total]).to eq(0)
      expect(result[:rate]).to be_nil
    end

    it "他ユーザーの明細は前年同月に混ざらない（テナント）" do
      other = create(:user)
      other_pm = create(:payment_method, user: other)
      create(:transaction, user: other, payment_method: other_pm, amount: 9999, date: Date.new(2025, 4, 10))

      expect(call(current_total: 6000)[:previous_total]).to eq(0)
    end
  end
end

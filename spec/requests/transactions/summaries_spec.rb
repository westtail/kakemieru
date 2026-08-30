require "rails_helper"

RSpec.describe "Transactions::Summaries", type: :request do
  let(:password) { "password" }
  let!(:user) { create(:user, password: password) }
  let!(:payment_method) { create(:payment_method, user: user) }
  let!(:food) { create(:category, user: user, name: "食費") }

  def sign_in
    post "/sign_in", params: { email_address: user.email_address, password: password }
  end

  def json
    JSON.parse(response.body)
  end

  describe "GET /transactions/summary" do
    it "認証済みは月次サマリー JSON を返す" do
      create(:transaction, user: user, payment_method: payment_method,
             amount: 5000, category: food, date: Date.new(2026, 4, 10))
      create(:transaction, user: user, payment_method: payment_method,
             amount: 1200, category: nil, date: Date.new(2026, 4, 12))
      sign_in

      get "/transactions/summary", params: { month: "2026-04" }

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("application/json")
      expect(json["month"]).to eq("2026-04")
      expect(json["total"]).to eq(6200)
      expect(json["categories"]).to eq([
        { "id" => food.id, "name" => "食費", "amount" => 5000, "count" => 1 },
        { "id" => nil, "name" => "未分類", "amount" => 1200, "count" => 1 }
      ])
    end

    it "直近6ヶ月の推移（monthly_totals）を同梱する（#153）" do
      create(:transaction, user: user, payment_method: payment_method,
             amount: 5000, category: food, date: Date.new(2026, 4, 10))
      create(:transaction, user: user, payment_method: payment_method,
             amount: 3000, category: food, date: Date.new(2026, 2, 10))
      sign_in

      get "/transactions/summary", params: { month: "2026-04" }

      totals = json["monthly_totals"]
      expect(totals.length).to eq(6)
      expect(totals.map { |t| t["month"] }).to eq(%w[2025-11 2025-12 2026-01 2026-02 2026-03 2026-04])
      expect(totals.last).to eq({ "month" => "2026-04", "total" => 5000 })
      expect(totals.find { |t| t["month"] == "2026-02" }["total"]).to eq(3000)
    end

    it "未ログインは 401（リダイレクトしない）" do
      get "/transactions/summary", params: { month: "2026-04" }
      expect(response).to have_http_status(:unauthorized)
    end

    it "month が不正な形式は 422" do
      sign_in
      get "/transactions/summary", params: { month: "2026-13" }
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "month 欠落は 422" do
      sign_in
      get "/transactions/summary"
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "YYYY-MM に厳密でない month（末尾ゴミ・桁不足）は 422" do
      sign_in
      [ "2026-04-99", "2026-04garbage", "2026-4", "2026/04" ].each do |bad|
        get "/transactions/summary", params: { month: bad }
        expect(response).to have_http_status(:unprocessable_entity), "expected 422 for #{bad.inspect}"
      end
    end
  end
end

require "rails_helper"

RSpec.describe "Home", type: :request do
  describe "GET /" do
    before { get root_path }

    it "returns 200" do
      expect(response).to have_http_status(:success)
    end

    it "displays app title" do
      expect(response.body).to include("掛け見える - 家計簿アプリ")
    end

    it "shows running status" do
      expect(response.body).to match(/アプリケーション稼働中/)
    end
  end

  describe "GET /home/index" do
    it "returns 200" do
      get home_index_path
      expect(response).to have_http_status(:success)
    end
  end
end

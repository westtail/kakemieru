require "rails_helper"

RSpec.describe "Home", type: :request do
  describe "GET /" do
    context "未認証のとき" do
      it "ログイン画面にリダイレクトする" do
        get root_path
        expect(response).to redirect_to("/sign_in")
      end
    end

    context "認証済みのとき" do
      let(:password) { "password123" }
      let(:user) { create(:user, password: password) }

      before do
        post "/sign_in", params: { email_address: user.email_address, password: password }
      end

      it "ダッシュボード（Stimulus + 円グラフ canvas）を表示する" do
        get root_path
        expect(response).to have_http_status(:success)
        expect(response.body).to include('data-controller="dashboard"')
        expect(response.body).to include('data-dashboard-target="canvas"')
        expect(response.body).to include("支出合計")
      end

      it "サマリー/明細の URL と取り込み導線を渡す" do
        get root_path
        expect(response.body).to include(summary_transactions_path, transactions_path, new_import_path)
      end

      it "?month= を初期月として月ラベルに反映する" do
        get root_path, params: { month: "2026-03" }
        expect(response.body).to include('data-dashboard-month-value="2026-03"')
        expect(response.body).to include("2026年3月")
      end
    end
  end
end

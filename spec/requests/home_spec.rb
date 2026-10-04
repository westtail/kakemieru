require "rails_helper"

RSpec.describe "Home", type: :request do
  describe "GET /" do
    context "未認証のとき" do
      it "公開ランディングページを表示する（リダイレクトしない）" do
        get root_path
        expect(response).to have_http_status(:success)
        expect(response.body).to include("家計を、", "見える化。")
        expect(response.body).to include("できること", "使い方は3ステップ")
      end

      it "新規登録・ログインへの導線を渡す" do
        get root_path
        expect(response.body).to include(new_registration_path, new_session_path)
      end

      it "カテゴリ別ドーナツ（プレビュー）にアクセシブルな名前を付ける" do
        get root_path
        expect(response.body).to include('aria-label="カテゴリ別支出の円グラフ"')
      end

      it "ログイン必須のダッシュボード（Stimulus canvas）は出さない" do
        get root_path
        expect(response.body).not_to include('data-controller="dashboard"')
      end

      it "主要機能（できること）を3つ紹介する" do
        get root_path
        expect(response.body).to include("CSVで自動集計", "カテゴリを自動分類", "月次ダッシュボード")
      end

      it "使い方3ステップを説明する" do
        get root_path
        expect(response.body).to include("アカウント登録", "CSVをアップロード", "グラフで確認")
      end

      it "登録への導線を複数（ヘッダー・ヒーロー・末尾CTA）置く" do
        get root_path
        expect(response.body.scan(new_registration_path).size).to be >= 3
      end

      it "未ログイン向けにはアプリ内ナビ（明細・カテゴリ・支払方法）を出さない" do
        get root_path
        expect(response.body).not_to include(transactions_path, categories_path, payment_methods_path)
      end

      it "フッターに現在の年を表示する" do
        get root_path
        expect(response.body).to include("#{Date.current.year} 掛け見える")
      end

      it "LP でデザイン用フォント（Google Fonts）を読み込む" do
        get root_path
        expect(response.body).to include("fonts.googleapis.com")
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

      it "認証後の画面では Google Fonts を読み込まない（LP 限定・プライバシー）" do
        get root_path
        expect(response.body).not_to include("fonts.googleapis.com")
      end
    end
  end
end

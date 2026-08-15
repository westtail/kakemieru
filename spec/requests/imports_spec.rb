require "rails_helper"

RSpec.describe "Imports", type: :request do
  let(:password) { "password" }
  let!(:user) { create(:user, password: password) }
  let!(:payment_method) { create(:payment_method, user: user, name: "楽天カード") }

  def sign_in
    post "/sign_in", params: { email_address: user.email_address, password: password }
  end

  def csv_upload(text, filename: "rakuten.csv")
    Rack::Test::UploadedFile.new(StringIO.new(text.encode("Shift_JIS")), "text/csv", original_filename: filename)
  end

  let(:valid_csv) do
    <<~CSV
      利用日,利用店名・商品名,利用者,支払方法,利用金額,支払手数料,支払総額
      2026/01/15,ローソン,本人,1回払い,"1,200",0,"1,200"
      2026/01/20,Amazon,本人,1回払い,3500,0,3500
    CSV
  end

  describe "未ログイン" do
    it "取り込み画面・一覧はログイン画面へリダイレクト" do
      get "/imports/new"
      expect(response).to redirect_to("/sign_in")
      get "/imports"
      expect(response).to redirect_to("/sign_in")
    end
  end

  describe "GET /imports/new" do
    it "取り込みフォームを表示する" do
      sign_in
      get "/imports/new"
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("CSV取り込み", "支払方法")
    end
  end

  describe "POST /imports（取り込み保存）" do
    before { sign_in }

    it "正常CSVで Import + 明細を作成し、取り込んだ月の一覧へ遷移する" do
      expect do
        post "/imports", params: { import: { payment_method_id: payment_method.id, file: csv_upload(valid_csv) } }
      end.to change { user.transactions.count }.by(2).and change { user.imports.count }.by(1)

      expect(response).to redirect_to("/transactions?month=2026-01")
      follow_redirect!
      expect(flash[:notice]).to include("2件")
    end

    it "同じファイルの再取り込みは重複エラーで再描画する" do
      post "/imports", params: { import: { payment_method_id: payment_method.id, file: csv_upload(valid_csv) } }
      expect do
        post "/imports", params: { import: { payment_method_id: payment_method.id, file: csv_upload(valid_csv) } }
      end.not_to change { user.transactions.count }
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("取り込み済み")
    end

    it "不正CSVはエラーを表示し何も作らない" do
      expect do
        post "/imports", params: { import: { payment_method_id: payment_method.id, file: csv_upload("ゴミ,データ\n1,2") } }
      end.not_to change { user.imports.count }
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("error-messages")
    end

    it "他ユーザーの支払方法では取り込めない" do
      other_pm = create(:payment_method, user: create(:user), name: "他人カード")
      expect do
        post "/imports", params: { import: { payment_method_id: other_pm.id, file: csv_upload(valid_csv) } }
      end.not_to change(Import, :count)
      expect(response).to redirect_to("/imports/new")
    end
  end

  describe "GET /imports（履歴一覧）" do
    it "自分の取り込み履歴を表示する" do
      sign_in
      post "/imports", params: { import: { payment_method_id: payment_method.id, file: csv_upload(valid_csv) } }

      get "/imports"
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("楽天カード", "rakuten.csv")
    end
  end
end

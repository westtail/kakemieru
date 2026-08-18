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
      expect(response.body).to include("CSVから取り込む", "支払方法")
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

    it "UTF-8 で保存された CSV でも取り込める（Excel 保存等）" do
      utf8_file = Rack::Test::UploadedFile.new(
        StringIO.new(valid_csv), "text/csv", original_filename: "rakuten_utf8.csv"
      )
      expect do
        post "/imports", params: { import: { payment_method_id: payment_method.id, file: utf8_file } }
      end.to change { user.transactions.count }.by(2)
      expect(response).to redirect_to("/transactions?month=2026-01")
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

    it "支払方法未選択では取り込めず、案内へ戻す" do
      expect do
        post "/imports", params: { import: { payment_method_id: "", file: csv_upload(valid_csv) } }
      end.not_to change(Import, :count)
      expect(response).to redirect_to("/imports/new")
      expect(flash[:alert]).to be_present
    end

    it "他ユーザーの支払方法では取り込めない" do
      other_pm = create(:payment_method, user: create(:user), name: "他人カード")
      expect do
        post "/imports", params: { import: { payment_method_id: other_pm.id, file: csv_upload(valid_csv) } }
      end.not_to change(Import, :count)
      expect(response).to redirect_to("/imports/new")
    end
  end

  describe "GET /imports/new（手動セクション）" do
    it "手動まとめ入力のセクションを表示する" do
      sign_in
      get "/imports/new"
      expect(response.body).to include("手動でまとめて入力", "デフォルト支払方法")
    end
  end

  describe "POST /imports/manual（手動まとめ入力）" do
    before { sign_in }

    it "複数行を Import(manual_bulk) + 明細として保存し、月別一覧へ遷移する" do
      expect do
        post "/imports/manual", params: { manual: {
          payment_method_id: payment_method.id,
          transactions: [
            { date: "2026-01-15", merchant_name: "ローソン", amount: "300", category_id: "", payment_method_id: "" },
            { date: "2026-01-20", merchant_name: "自販機", amount: "150", category_id: "", payment_method_id: "" }
          ]
        } }
      end.to change { user.transactions.count }.by(2).and change { user.imports.count }.by(1)

      expect(user.imports.last.source_type).to eq("manual_bulk")
      expect(response).to redirect_to("/transactions?month=2026-01")
      follow_redirect!
      expect(flash[:notice]).to include("2件")
    end

    it "入力不備は 422 で再描画する（Import は作らない）" do
      expect do
        post "/imports/manual", params: { manual: {
          payment_method_id: payment_method.id,
          transactions: [ { date: "2026-01-15", merchant_name: "", amount: "", category_id: "", payment_method_id: "" } ]
        } }
      end.not_to change { user.imports.count }
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("error-messages")
    end

    it "デフォルト支払方法未選択では案内へ戻す" do
      post "/imports/manual", params: { manual: {
        payment_method_id: "",
        transactions: [ { date: "2026-01-15", merchant_name: "X", amount: "100" } ]
      } }
      expect(response).to redirect_to("/imports/new")
      expect(flash[:alert]).to be_present
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

  describe "取り込み取り消し" do
    before { sign_in }

    # CSV を取り込み、作成された Import（明細2件付き）を返す。
    def import_valid_csv
      post "/imports", params: { import: { payment_method_id: payment_method.id, file: csv_upload(valid_csv) } }
      user.imports.order(:id).last
    end

    describe "GET /imports/:id/cancel_confirm" do
      it "対象件数と警告を表示する" do
        import = import_valid_csv
        get cancel_confirm_import_path(import)
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("2件", "取り消せません")
      end

      it "他ユーザーの取り込みは 404" do
        other = create(:user)
        others_import = create(:import, user: other)
        get cancel_confirm_import_path(others_import)
        expect(response).to have_http_status(:not_found)
      end
    end

    describe "DELETE /imports/:id/cancel" do
      it "紐づく明細をソフト削除し、Import レコードは残す" do
        import = import_valid_csv

        expect do
          delete cancel_import_path(import)
        end.to change { user.transactions.not_deleted.count }.by(-2)

        expect(Import.exists?(import.id)).to be(true)
        expect(import.transactions.where.not(deleted_at: nil).count).to eq(2)
        expect(response).to redirect_to("/imports")
        expect(flash[:notice]).to include("2件")
      end

      it "取り消した明細は一覧に表示されない" do
        import = import_valid_csv
        delete cancel_import_path(import)

        get "/transactions", params: { month: "2026-01" }
        expect(response.body).not_to include("ローソン")
        expect(response.body).not_to include("Amazon")
      end

      it "取り消し後も同じファイルの再取り込みは重複エラー（file_hash 温存）" do
        import = import_valid_csv
        delete cancel_import_path(import)

        expect do
          post "/imports", params: { import: { payment_method_id: payment_method.id, file: csv_upload(valid_csv) } }
        end.not_to change { user.transactions.count }
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include("取り込み済み")
      end

      it "他ユーザーの取り込みは 404" do
        other = create(:user)
        others_import = create(:import, user: other)
        delete cancel_import_path(others_import)
        expect(response).to have_http_status(:not_found)
      end

      it "取り消せる明細が無ければ（二重実行）案内メッセージを出す" do
        import = import_valid_csv
        delete cancel_import_path(import) # 1回目
        delete cancel_import_path(import) # 2回目は 0 件
        expect(response).to redirect_to("/imports")
        expect(flash[:alert]).to include("取り消せる明細はありません")
      end
    end
  end
end

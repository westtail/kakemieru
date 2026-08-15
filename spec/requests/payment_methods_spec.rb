require "rails_helper"

RSpec.describe "PaymentMethods", type: :request do
  let(:password) { "password" }
  let!(:user) { create(:user, password: password) }

  def sign_in
    post "/sign_in", params: { email_address: user.email_address, password: password }
  end

  describe "未ログイン" do
    it "一覧はログイン画面へリダイレクトする" do
      get "/payment_methods"
      expect(response).to redirect_to("/sign_in")
    end
  end

  describe "GET /payment_methods（一覧）" do
    it "アクティブな支払方法を表示する" do
      create(:payment_method, user: user, name: "楽天カード")
      create(:payment_method, :cash, user: user)
      sign_in

      get "/payment_methods"
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("楽天カード", "現金")
    end
  end

  describe "POST /payment_methods（追加）" do
    before { sign_in }

    it "支払方法を追加できる" do
      expect do
        post "/payment_methods", params: { payment_method: { name: "PayPay", payment_type: "qr" } }
      end.to change { user.payment_methods.count }.by(1)

      created = user.payment_methods.order(:id).last
      expect(created.name).to eq("PayPay")
      expect(created.payment_type).to eq("qr")
      expect(response).to redirect_to("/payment_methods")
    end

    it "名前が重複すると追加できず、エラーを再描画する" do
      create(:payment_method, user: user, name: "楽天カード")
      expect do
        post "/payment_methods", params: { payment_method: { name: "楽天カード", payment_type: "credit" } }
      end.not_to change { user.payment_methods.count }
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("error-messages")
    end

    it "payment_type=cash を直接送っても現金は作れない（サーバー側で不変条件を強制）" do
      expect do
        post "/payment_methods", params: { payment_method: { name: "予備現金", payment_type: "cash" } }
      end.not_to change { user.payment_methods.where(payment_type: "cash").count }
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "PATCH /payment_methods/:id（名前/種別変更）" do
    before { sign_in }

    it "名称を変更できる" do
      payment_method = create(:payment_method, user: user, name: "楽天カード")
      patch "/payment_methods/#{payment_method.id}", params: { payment_method: { name: "楽天プレミアム", payment_type: "credit" } }
      expect(payment_method.reload.name).to eq("楽天プレミアム")
      expect(response).to redirect_to("/payment_methods")
    end
  end

  describe "DELETE /payment_methods/:id（削除）" do
    before { sign_in }

    it "現金以外は削除できる" do
      payment_method = create(:payment_method, user: user, name: "楽天カード")
      expect do
        delete "/payment_methods/#{payment_method.id}"
      end.to change { user.payment_methods.count }.by(-1)
      expect(response).to redirect_to("/payment_methods")
    end

    it "現金は削除できない（拒否して残る）" do
      cash = create(:payment_method, :cash, user: user)
      expect do
        delete "/payment_methods/#{cash.id}"
      end.not_to change { user.payment_methods.count }
      expect(response).to redirect_to("/payment_methods")
      expect(flash[:alert]).to be_present
    end

    it "明細を持つ支払方法は削除でなくアーカイブされる（物理削除しない）" do
      payment_method = create(:payment_method, user: user, name: "楽天カード")
      create(:transaction, user: user, payment_method: payment_method)

      expect do
        delete "/payment_methods/#{payment_method.id}"
      end.not_to change { user.payment_methods.count }
      expect(payment_method.reload.archived_at).to be_present
      expect(response).to redirect_to("/payment_methods")
    end

    it "現金の種別変更で削除ガードを回避できない（種別は変わらず削除も不可）" do
      cash = create(:payment_method, :cash, user: user)
      # 種別を credit に変えて cash? を false にしようとしても、サーバー側で種別変更を拒否する。
      patch "/payment_methods/#{cash.id}", params: { payment_method: { payment_type: "credit" } }
      expect(cash.reload.payment_type).to eq("cash")

      expect do
        delete "/payment_methods/#{cash.id}"
      end.not_to change { user.payment_methods.count }
    end
  end

  describe "所有権による認可（他ユーザーの支払方法）" do
    let(:other) { create(:user) }
    let!(:others_payment_method) { create(:payment_method, user: other, name: "他人のカード") }

    before { sign_in }

    it "他ユーザーの支払方法は変更できない（404・不変）" do
      patch "/payment_methods/#{others_payment_method.id}", params: { payment_method: { name: "乗っ取り" } }
      expect(response).to have_http_status(:not_found)
      expect(others_payment_method.reload.name).to eq("他人のカード")
    end

    it "他ユーザーの支払方法は削除できない（404・不変）" do
      expect do
        delete "/payment_methods/#{others_payment_method.id}"
      end.not_to change(PaymentMethod, :count)
      expect(response).to have_http_status(:not_found)
    end
  end
end

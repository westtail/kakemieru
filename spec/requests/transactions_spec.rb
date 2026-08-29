require "rails_helper"

RSpec.describe "Transactions", type: :request do
  let(:password) { "password" }
  let!(:user) { create(:user, password: password) }
  let!(:payment_method) { create(:payment_method, user: user, name: "楽天カード") }

  def sign_in
    post "/sign_in", params: { email_address: user.email_address, password: password }
  end

  describe "未ログイン" do
    it "一覧・新規はログイン画面へリダイレクトする" do
      get "/transactions"
      expect(response).to redirect_to("/sign_in")
      get "/transactions/new"
      expect(response).to redirect_to("/sign_in")
    end
  end

  describe "GET /transactions/new" do
    it "入力フォームを表示する" do
      sign_in
      get "/transactions/new"
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("利用日", "金額", "店舗名")
    end
  end

  describe "POST /transactions（手動1件入力）" do
    before { sign_in }

    it "明細を作成する（import_id = NULL・保存後に月別一覧へ）" do
      category = create(:category, user: user, name: "食費")
      expect do
        post "/transactions", params: {
          transaction: { date: "2026-01-15", amount: 1200, merchant_name: "ローソン",
                         payment_method_id: payment_method.id, category_id: category.id }
        }
      end.to change { user.transactions.count }.by(1)

      created = user.transactions.order(:id).last
      expect(created.import_id).to be_nil
      expect(created.amount).to eq(1200)
      expect(created.effective_amount).to eq(1200)
      expect(response).to redirect_to("/transactions?month=2026-01")
    end

    it "カテゴリ未選択（未分類）でも作成できる" do
      expect do
        post "/transactions", params: {
          transaction: { date: "2026-01-15", amount: 500, merchant_name: "自販機",
                         payment_method_id: payment_method.id, category_id: "" }
        }
      end.to change { user.transactions.count }.by(1)
      expect(user.transactions.order(:id).last.category_id).to be_nil
    end

    it "必須項目が空だとエラーを再描画する" do
      expect do
        post "/transactions", params: {
          transaction: { date: "2026-01-15", amount: "", merchant_name: "",
                         payment_method_id: payment_method.id }
        }
      end.not_to change { user.transactions.count }
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("error-messages")
    end

    it "他ユーザーの支払方法/カテゴリは紐づけられない（テナント整合）" do
      other = create(:user)
      others_pm = create(:payment_method, user: other, name: "他人カード")
      others_cat = create(:category, user: other, name: "他人カテゴリ")

      expect do
        post "/transactions", params: {
          transaction: { date: "2026-01-15", amount: 100, merchant_name: "x",
                         payment_method_id: others_pm.id, category_id: others_cat.id }
        }
      end.not_to change(Transaction, :count)
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "GET /transactions（月別一覧）" do
    before { sign_in }

    it "指定月の明細のみ表示する" do
      in_month = create(:transaction, user: user, payment_method: payment_method, date: Date.new(2026, 1, 10), merchant_name: "1月の店")
      other_month = create(:transaction, user: user, payment_method: payment_method, date: Date.new(2026, 2, 10), merchant_name: "2月の店")

      get "/transactions", params: { month: "2026-01" }
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("1月の店")
      expect(response.body).not_to include("2月の店")
    end

    it "他ユーザーの明細は表示しない" do
      other = create(:user)
      others_pm = create(:payment_method, user: other)
      create(:transaction, user: other, payment_method: others_pm, date: Date.new(2026, 1, 10), merchant_name: "他人の明細")

      get "/transactions", params: { month: "2026-01" }
      expect(response.body).not_to include("他人の明細")
    end
  end

  describe "GET /transactions（絞り込み）" do
    before { sign_in }

    let(:food) { create(:category, user: user, name: "食費") }
    let(:transport) { create(:category, user: user, name: "交通費") }

    # 同一月（2026-01）に、カテゴリ別・キーワード別の明細を用意する。
    let!(:food_tx) do
      create(:transaction, user: user, payment_method: payment_method,
             date: Date.new(2026, 1, 10), merchant_name: "スーパー", category: food)
    end
    let!(:transport_tx) do
      create(:transaction, user: user, payment_method: payment_method,
             date: Date.new(2026, 1, 11), merchant_name: "鉄道", category: transport)
    end
    let!(:uncategorized_tx) do
      create(:transaction, user: user, payment_method: payment_method,
             date: Date.new(2026, 1, 12), merchant_name: "自販機", category: nil)
    end

    it "カテゴリ指定でそのカテゴリの明細のみ表示する" do
      get "/transactions", params: { month: "2026-01", category: food.id }
      expect(response.body).to include("スーパー")
      expect(response.body).not_to include("鉄道")
      expect(response.body).not_to include("自販機")
    end

    it "category 空で未分類のみ表示する" do
      get "/transactions", params: { month: "2026-01", category: "" }
      expect(response.body).to include("自販機")
      expect(response.body).not_to include("スーパー")
      expect(response.body).not_to include("鉄道")
    end

    it "category=all（既定）で全件表示する" do
      get "/transactions", params: { month: "2026-01", category: "all" }
      expect(response.body).to include("スーパー", "鉄道", "自販機")
    end

    it "キーワードは店舗名の前方一致で絞り込む（部分一致は除外）" do
      create(:transaction, user: user, payment_method: payment_method,
             date: Date.new(2026, 1, 13), merchant_name: "スターバックス")
      # 「スター」を含むが先頭ではない → 前方一致では出ない
      create(:transaction, user: user, payment_method: payment_method,
             date: Date.new(2026, 1, 14), merchant_name: "駅スター")

      get "/transactions", params: { month: "2026-01", q: "スター" }
      expect(response.body).to include("スターバックス")
      expect(response.body).not_to include("駅スター")
      expect(response.body).not_to include("スーパー")
    end

    it "キーワードの LIKE ワイルドカード（_ や %）をリテラルとして扱う" do
      # "_" をエスケープしないと "A_B" は「A + 任意1文字 + B」に一致してしまう
      create(:transaction, user: user, payment_method: payment_method,
             date: Date.new(2026, 1, 15), merchant_name: "A_B商店")
      create(:transaction, user: user, payment_method: payment_method,
             date: Date.new(2026, 1, 16), merchant_name: "AXB商店")

      get "/transactions", params: { month: "2026-01", q: "A_B" }
      expect(response.body).to include("A_B商店")
      expect(response.body).not_to include("AXB商店")
    end

    it "他ユーザーのカテゴリ id を指定しても自分の明細は漏れない" do
      others_category = create(:category, user: create(:user), name: "他人カテゴリ")

      get "/transactions", params: { month: "2026-01", category: others_category.id }
      expect(response.body).not_to include("スーパー")
      expect(response.body).not_to include("自販機")
      expect(response.body).to include("該当する明細はありません")
    end

    it "該当する明細がない月はメッセージを表示する" do
      get "/transactions", params: { month: "2020-01" }
      expect(response.body).to include("該当する明細はありません")
    end

    it "配列/ハッシュ型の細工パラメータでも 500 にならない" do
      get "/transactions", params: { month: [ "x" ], category: { x: "1" }, q: [ "y" ] }
      expect(response).to have_http_status(:ok)
    end

    it "訂正済みの行にバッジと編集リンクを表示する" do
      corrected = create(:transaction, user: user, payment_method: payment_method,
                         date: Date.new(2026, 1, 10), merchant_name: "訂正済店", amount: 1000, amount_override: 800)

      get "/transactions", params: { month: "2026-01" }
      expect(response.body).to include("訂正")
      expect(response.body).to include(edit_transaction_path(corrected))
    end
  end

  describe "GET /transactions（並び替え・#147）" do
    before { sign_in }

    # 店舗名/金額/日付/カテゴリ/支払方法が別々の並びになるよう作る。
    # 名前は先頭 ASCII（A/B/C）で collation に依らず一意に並ぶようにする。
    let(:pm_a) { create(:payment_method, user: user, name: "Aカード") }
    let(:pm_b) { create(:payment_method, user: user, name: "Bカード") }
    let(:cat_a) { create(:category, user: user, name: "Aカテゴリ") }
    let(:cat_b) { create(:category, user: user, name: "Bカテゴリ") }

    # 各次元の並びが互いに（特に既定の日付降順と）異なるよう配置する。
    #   merchant  amount  date   category  payment
    # C  Cショップ  100    1/20   Bカテゴリ  Bカード
    # A  Aショップ  300    1/15   未分類     Aカード
    # B  Bショップ  200    1/10   Aカテゴリ  Aカード
    let!(:t1) do
      create(:transaction, user: user, payment_method: pm_b, category: cat_b,
             merchant_name: "Cショップ", amount: 100, date: Date.new(2026, 1, 20))
    end
    let!(:t2) do
      create(:transaction, user: user, payment_method: pm_a, category: nil,
             merchant_name: "Aショップ", amount: 300, date: Date.new(2026, 1, 15))
    end
    let!(:t3) do
      create(:transaction, user: user, payment_method: pm_a, category: cat_a,
             merchant_name: "Bショップ", amount: 200, date: Date.new(2026, 1, 10))
    end

    # 店舗名（行に一意で現れる）の出現位置で並び順を判定する。
    def positions(*merchants)
      merchants.map { |m| response.body.index(m) }
    end

    it "既定は日付降順（sort 無指定で現状維持）" do
      get "/transactions", params: { month: "2026-01" }
      c, a, b = positions("Cショップ", "Aショップ", "Bショップ") # 1/20 > 1/15 > 1/10
      expect(c).to be < a
      expect(a).to be < b
    end

    it "店舗名の昇順・降順で並ぶ" do
      get "/transactions", params: { month: "2026-01", sort: "merchant", direction: "asc" }
      a, b, c = positions("Aショップ", "Bショップ", "Cショップ")
      expect(a).to be < b
      expect(b).to be < c

      get "/transactions", params: { month: "2026-01", sort: "merchant", direction: "desc" }
      a, b, c = positions("Aショップ", "Bショップ", "Cショップ")
      expect(a).to be > b
      expect(b).to be > c
    end

    it "金額の昇順で並ぶ（100 < 200 < 300）" do
      get "/transactions", params: { month: "2026-01", sort: "amount", direction: "asc" }
      c, b, a = positions("Cショップ", "Bショップ", "Aショップ") # 100 / 200 / 300
      expect(c).to be < b
      expect(b).to be < a
    end

    it "カテゴリ名の昇順で並ぶ（Aカテゴリ→Bカテゴリ→未分類は末尾）" do
      get "/transactions", params: { month: "2026-01", sort: "category", direction: "asc" }
      # Aカテゴリ(t3/Bショップ) → Bカテゴリ(t1/Cショップ) → 未分類(t2/Aショップ)
      b, c, a = positions("Bショップ", "Cショップ", "Aショップ")
      expect(b).to be < c
      expect(c).to be < a
    end

    it "カテゴリ名の降順でも未分類は末尾のまま（NULLS LAST 固定）" do
      get "/transactions", params: { month: "2026-01", sort: "category", direction: "desc" }
      # Bカテゴリ(t1/Cショップ) → Aカテゴリ(t3/Bショップ) → 未分類(t2/Aショップ) は末尾。
      c, b, a = positions("Cショップ", "Bショップ", "Aショップ")
      expect(c).to be < b
      expect(b).to be < a
    end

    it "支払方法名の昇順で並ぶ（Aカード→Bカード）" do
      get "/transactions", params: { month: "2026-01", sort: "payment_method", direction: "asc" }
      # pm_a(t2/Aショップ, t3/Bショップ) が pm_b(t1/Cショップ) より先。
      expect(response.body.index("Aショップ")).to be < response.body.index("Cショップ")
      expect(response.body.index("Bショップ")).to be < response.body.index("Cショップ")
    end

    it "絞り込みと併用してもソートできる（金額降順）" do
      get "/transactions", params: { month: "2026-01", category: "all", sort: "amount", direction: "desc" }
      a, b, c = positions("Aショップ", "Bショップ", "Cショップ") # 300 > 200 > 100
      expect(a).to be < b
      expect(b).to be < c
    end

    it "不正な sort/direction は既定（日付降順）に倒れて 200（SQLi にならない）" do
      get "/transactions", params: { month: "2026-01", sort: "name); DROP TABLE users; --", direction: "sideways" }
      expect(response).to have_http_status(:ok)
      c, a, b = positions("Cショップ", "Aショップ", "Bショップ") # 既定＝日付降順
      expect(c).to be < a
      expect(a).to be < b
    end
  end

  describe "GET /transactions/:id/edit" do
    before { sign_in }

    it "自分の明細の編集画面を表示する（原本は表示のみ）" do
      transaction = create(:transaction, user: user, payment_method: payment_method,
                           date: Date.new(2026, 1, 15), amount: 1234, description: "原本メモ")
      get edit_transaction_path(transaction)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("1,234", "原本メモ", "merchant_name")
    end

    it "他ユーザーの明細は 404" do
      other = create(:user)
      others_tx = create(:transaction, user: other, payment_method: create(:payment_method, user: other))
      get edit_transaction_path(others_tx)
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "PATCH /transactions/:id" do
    before { sign_in }

    let!(:transaction) do
      create(:transaction, user: user, payment_method: payment_method,
             date: Date.new(2026, 1, 15), amount: 1000, merchant_name: "元の店")
    end

    it "amount_override を保存すると effective_amount が更新される" do
      patch transaction_path(transaction), params: { transaction: { amount_override: 800 } }
      transaction.reload
      expect(transaction.amount).to eq(1000) # 原本は不変
      expect(transaction.effective_amount).to eq(800)
      expect(response).to redirect_to("/transactions?month=2026-01")
    end

    it "date_override を保存すると effective_date が更新され、その月へ遷移する" do
      patch transaction_path(transaction), params: { transaction: { date_override: "2026-02-20" } }
      transaction.reload
      expect(transaction.date).to eq(Date.new(2026, 1, 15)) # 原本は不変
      expect(transaction.effective_date).to eq(Date.new(2026, 2, 20))
      expect(response).to redirect_to("/transactions?month=2026-02")
    end

    it "amount_override を空欄で保存すると訂正が解除され原本に戻る" do
      transaction.update!(amount_override: 800)
      expect(transaction.reload.effective_amount).to eq(800)

      patch transaction_path(transaction), params: { transaction: { amount_override: "" } }
      transaction.reload
      expect(transaction.amount_override).to be_nil
      expect(transaction.effective_amount).to eq(1000) # 原本へ戻る
      expect(transaction.corrected?).to be(false)
    end

    it "merchant_name / category_id を更新できる" do
      category = create(:category, user: user, name: "食費")
      patch transaction_path(transaction), params: { transaction: { merchant_name: "新しい店", category_id: category.id } }
      transaction.reload
      expect(transaction.merchant_name).to eq("新しい店")
      expect(transaction.category_id).to eq(category.id)
    end

    it "不正値（店舗名空・金額訂正が非整数・不正日付）は 422 で再描画し原本を変えない" do
      patch transaction_path(transaction), params: { transaction: { merchant_name: "" } }
      expect(response).to have_http_status(:unprocessable_entity)

      patch transaction_path(transaction), params: { transaction: { amount_override: "abc" } }
      expect(response).to have_http_status(:unprocessable_entity)

      patch transaction_path(transaction), params: { transaction: { date_override: "not-a-date" } }
      expect(response).to have_http_status(:unprocessable_entity)

      transaction.reload
      expect(transaction.effective_amount).to eq(1000)
      expect(transaction.effective_date).to eq(Date.new(2026, 1, 15))
    end

    it "他ユーザーの明細の更新は 404" do
      other = create(:user)
      others_tx = create(:transaction, user: other, payment_method: create(:payment_method, user: other))
      patch transaction_path(others_tx), params: { transaction: { merchant_name: "乗っ取り" } }
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "PATCH /transactions/:id/categorize（カテゴリ即時変更・Turbo Stream）" do
    before { sign_in }

    let!(:transaction) do
      create(:transaction, user: user, payment_method: payment_method,
             date: Date.new(2026, 1, 15), merchant_name: "コンビニ", category: nil)
    end
    let(:food) { create(:category, user: user, name: "食費") }

    it "カテゴリを更新し、該当行を差し替える Turbo Stream を返す" do
      patch categorize_transaction_path(transaction),
            params: { transaction: { category_id: food.id } }, as: :turbo_stream

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      expect(response.body).to include('action="replace"', "transaction_#{transaction.id}")
      expect(transaction.reload.category_id).to eq(food.id)
    end

    it "未分類（空）へ戻せる" do
      transaction.update!(category: food)
      patch categorize_transaction_path(transaction),
            params: { transaction: { category_id: "" } }, as: :turbo_stream
      expect(transaction.reload.category_id).to be_nil
    end

    it "他ユーザーのカテゴリ id では変更されない（500 にしない）" do
      others_category = create(:category, user: create(:user), name: "他人カテゴリ")
      patch categorize_transaction_path(transaction),
            params: { transaction: { category_id: others_category.id } }, as: :turbo_stream
      expect(response).to have_http_status(:ok)
      expect(transaction.reload.category_id).to be_nil
    end

    it "存在しないカテゴリ id でも 500 にせず変更しない（FK 違反回避）" do
      patch categorize_transaction_path(transaction),
            params: { transaction: { category_id: 999_999 } }, as: :turbo_stream
      expect(response).to have_http_status(:ok)
      expect(transaction.reload.category_id).to be_nil
    end

    it "検証通過後にカテゴリが消えるレース（FK 違反）でも 500 にせず行を返す" do
      # 検証は通るが書き込みで FK 違反になる稀なレースを再現する。
      allow_any_instance_of(Transaction).to receive(:update).and_raise(ActiveRecord::InvalidForeignKey)
      patch categorize_transaction_path(transaction),
            params: { transaction: { category_id: food.id } }, as: :turbo_stream
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("transaction_#{transaction.id}")
    end

    it "他ユーザーの明細は 404" do
      other = create(:user)
      others_tx = create(:transaction, user: other, payment_method: create(:payment_method, user: other))
      patch categorize_transaction_path(others_tx),
            params: { transaction: { category_id: food.id } }, as: :turbo_stream
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "DELETE /transactions/:id（ソフト削除・Turbo Stream）" do
    before { sign_in }

    let!(:transaction) do
      create(:transaction, user: user, payment_method: payment_method,
             date: Date.new(2026, 1, 15), merchant_name: "消す明細")
    end

    it "deleted_at をセットし、該当行を削除する Turbo Stream を返す" do
      delete transaction_path(transaction), as: :turbo_stream

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      expect(response.body).to include('action="remove"', "transaction_#{transaction.id}")
      expect(transaction.reload.deleted_at).to be_present
    end

    it "削除後は一覧に表示されない" do
      delete transaction_path(transaction), as: :turbo_stream
      get "/transactions", params: { month: "2026-01" }
      expect(response.body).not_to include("消す明細")
    end

    it "他ユーザーの明細の削除は 404" do
      other = create(:user)
      others_tx = create(:transaction, user: other, payment_method: create(:payment_method, user: other))
      delete transaction_path(others_tx), as: :turbo_stream
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "PATCH /transactions/categorize_all（カテゴリ一括適用・#149）" do
    before { sign_in }

    let(:food) { create(:category, user: user, name: "食費") }
    let!(:t1) { create(:transaction, user: user, payment_method: payment_method, category: nil, merchant_name: "A", date: Date.new(2026, 1, 10)) }
    let!(:t2) { create(:transaction, user: user, payment_method: payment_method, category: nil, merchant_name: "B", date: Date.new(2026, 1, 11)) }
    let!(:t3) { create(:transaction, user: user, payment_method: payment_method, category: nil, merchant_name: "C", date: Date.new(2026, 1, 12)) }

    it "選択した複数明細に同じカテゴリを一括適用する" do
      patch categorize_all_transactions_path,
            params: { transaction_ids: [ t1.id, t2.id ], category_id: food.id, month: "2026-01" }

      expect(response).to redirect_to(transactions_path(month: "2026-01"))
      expect(t1.reload.category_id).to eq(food.id)
      expect(t2.reload.category_id).to eq(food.id)
      expect(t3.reload.category_id).to be_nil # 未選択は変わらない
      follow_redirect!
      expect(response.body).to include("2件")
    end

    it "category_id 空で未分類に一括設定できる" do
      t1.update!(category: food)
      patch categorize_all_transactions_path,
            params: { transaction_ids: [ t1.id ], category_id: "", month: "2026-01" }
      expect(t1.reload.category_id).to be_nil
    end

    it "現在の絞り込み/ソートを維持して一覧へ戻る" do
      patch categorize_all_transactions_path,
            params: { transaction_ids: [ t1.id ], category_id: food.id,
                      month: "2026-01", category: "", q: "", sort: "merchant", direction: "asc" }
      expect(response).to redirect_to(transactions_path(month: "2026-01", category: "", q: "", sort: "merchant", direction: "asc"))
    end

    it "他ユーザーの明細 id が混ざっても自分の明細だけ更新する（テナント保護）" do
      other = create(:user)
      others_tx = create(:transaction, user: other, payment_method: create(:payment_method, user: other), category: nil)

      patch categorize_all_transactions_path,
            params: { transaction_ids: [ t1.id, others_tx.id ], category_id: food.id, month: "2026-01" }

      expect(t1.reload.category_id).to eq(food.id)
      expect(others_tx.reload.category_id).to be_nil # 他人の明細は不変
    end

    it "他ユーザーのカテゴリは適用できず alert で戻す" do
      other = create(:user)
      others_category = create(:category, user: other, name: "他人")

      patch categorize_all_transactions_path,
            params: { transaction_ids: [ t1.id ], category_id: others_category.id, month: "2026-01" }

      expect(response).to redirect_to(transactions_path(month: "2026-01"))
      expect(flash[:alert]).to be_present
      expect(t1.reload.category_id).to be_nil # 変更されない
    end

    it "明細未選択なら alert で戻す（何も更新しない）" do
      patch categorize_all_transactions_path, params: { transaction_ids: [], category_id: food.id, month: "2026-01" }
      expect(response).to redirect_to(transactions_path(month: "2026-01"))
      expect(flash[:alert]).to be_present
    end

    it "配列でない細工パラメータでも 500 にならない" do
      patch categorize_all_transactions_path, params: { transaction_ids: "x", category_id: food.id, month: "2026-01" }
      expect(response).to have_http_status(:found) # redirect
    end

    it "配列-of-ハッシュの細工 transaction_ids でも 500 にならない" do
      patch categorize_all_transactions_path,
            params: { transaction_ids: [ { k: "1" } ], category_id: food.id, month: "2026-01" }
      expect(response).to have_http_status(:found)
      expect(flash[:alert]).to be_present # 有効な id が無く未選択扱い
    end

    it "配列型の category_id 細工は alert で拒否し、明細を変更しない" do
      t1.update!(category: food)
      patch categorize_all_transactions_path,
            params: { transaction_ids: [ t1.id ], category_id: [ food.id.to_s ], month: "2026-01" }
      expect(response).to redirect_to(transactions_path(month: "2026-01"))
      expect(flash[:alert]).to be_present
      expect(t1.reload.category_id).to eq(food.id) # 黙って未分類に消さない
    end

    it "未ログインはログイン画面へ" do
      delete "/sign_out"
      patch categorize_all_transactions_path, params: { transaction_ids: [ t1.id ], category_id: food.id }
      expect(response).to redirect_to("/sign_in")
    end
  end

  describe "POST /transactions/apply_rules（更新実行・ADR-0047）" do
    before { sign_in }

    let(:food) { create(:category, user: user, name: "食費") }

    it "店舗ルールを未分類明細へ一括適用し、件数を通知する" do
      create(:merchant_classification, user: user, category: food, merchant_name: "ローソン")
      t = create(:transaction, user: user, payment_method: payment_method,
                 merchant_name: "ローソン", category: nil, date: Date.new(2026, 1, 10))

      post apply_rules_transactions_path

      expect(t.reload.category_id).to eq(food.id)
      follow_redirect!
      expect(response.body).to include("1件")
    end

    it "一致する未分類が無ければその旨を通知する" do
      post apply_rules_transactions_path
      follow_redirect!
      expect(response.body).to include("適用できる未分類の明細はありませんでした")
    end

    it "未ログインはログイン画面へ" do
      delete "/sign_out"
      post apply_rules_transactions_path
      expect(response).to redirect_to("/sign_in")
    end
  end
end

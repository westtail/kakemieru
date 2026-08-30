require "rails_helper"

RSpec.describe RuleApplier, type: :service do
  let(:user) { create(:user) }
  let(:payment_method) { create(:payment_method, user: user) }
  let(:food) { create(:category, user: user, name: "食費") }
  let(:transport) { create(:category, user: user, name: "交通費") }
  let(:hobby) { create(:category, user: user, name: "娯楽") }

  def tx(merchant:, category: nil, amount: 1000, date: Date.new(2026, 1, 10))
    create(:transaction, user: user, payment_method: payment_method,
           merchant_name: merchant, category: category, amount: amount, date: date)
  end

  def apply
    described_class.new(user: user).call
  end

  it "未分類でルールに一致する明細へカテゴリを付け、更新件数を返す" do
    create(:merchant_classification, user: user, category: food, merchant_name: "ローソン")
    t = tx(merchant: "ローソン")

    expect(apply).to eq(1)
    expect(t.reload.category_id).to eq(food.id)
  end

  it "手動で分類済み（カテゴリあり）の明細は上書きしない" do
    create(:merchant_classification, user: user, category: food, merchant_name: "ローソン")
    t = tx(merchant: "ローソン", category: transport)

    expect(apply).to eq(0)
    expect(t.reload.category_id).to eq(transport.id)
  end

  it "ルールに一致しない未分類は変えない" do
    create(:merchant_classification, user: user, category: food, merchant_name: "ローソン")
    t = tx(merchant: "無関係店")

    expect(apply).to eq(0)
    expect(t.reload.category_id).to be_nil
  end

  it "正規化して一致する（大文字小文字・全角）" do
    create(:merchant_classification, user: user, category: food, merchant_name: "amazon")
    t = tx(merchant: "ＡＭＡＺＯＮ")

    expect(apply).to eq(1)
    expect(t.reload.category_id).to eq(food.id)
  end

  it "取り消し済み（ソフトデリート）明細は対象外" do
    create(:merchant_classification, user: user, category: food, merchant_name: "ローソン")
    t = tx(merchant: "ローソン")
    t.soft_delete!

    expect(apply).to eq(0)
  end

  it "他ユーザーの明細は触らない（テナント）" do
    create(:merchant_classification, user: user, category: food, merchant_name: "ローソン")
    tx(merchant: "ローソン") # 自分の未分類明細
    other = create(:user)
    other_pm = create(:payment_method, user: other)
    other_tx = create(:transaction, user: other, payment_method: other_pm,
                      merchant_name: "ローソン", category: nil, date: Date.new(2026, 1, 10))

    expect(apply).to eq(1) # 自分の1件だけ
    expect(other_tx.reload.category_id).to be_nil
  end

  it "店舗ルールが無ければ何もしない" do
    tx(merchant: "ローソン")
    expect(apply).to eq(0)
  end

  describe "特別ルール（ADR-0048）" do
    it "金額一致の特別ルールを適用し、note を description に追記する" do
      create(:special_rule, user: user, category: hobby, merchant_name: "楽天SP",
             amount_min: 1200, amount_max: 1200, note: "Netflix")
      t = tx(merchant: "楽天SP", amount: 1200)

      expect(apply).to eq(1)
      t.reload
      expect(t.category_id).to eq(hobby.id)
      expect(t.description).to include("Netflix")
    end

    it "特別ルールは店舗ルールより優先される" do
      create(:merchant_classification, user: user, category: food, merchant_name: "楽天SP")
      create(:special_rule, user: user, category: hobby, merchant_name: "楽天SP", amount_min: 1200, amount_max: 1200)
      t = tx(merchant: "楽天SP", amount: 1200)

      apply
      expect(t.reload.category_id).to eq(hobby.id)
    end

    it "特別ルールに外れると店舗ルールへフォールバックする" do
      create(:merchant_classification, user: user, category: food, merchant_name: "楽天SP")
      create(:special_rule, user: user, category: hobby, merchant_name: "楽天SP", amount_min: 1200, amount_max: 1200)
      t = tx(merchant: "楽天SP", amount: 999)

      apply
      expect(t.reload.category_id).to eq(food.id)
    end

    it "未分類へ戻して再適用しても note を二重に追記しない（冪等）" do
      create(:special_rule, user: user, category: hobby, merchant_name: "楽天SP",
             amount_min: 1200, amount_max: 1200, note: "Netflix")
      t = tx(merchant: "楽天SP", amount: 1200)

      apply
      first = t.reload.description
      expect(first).to include("Netflix")

      # 未分類へ戻す（description は追記済みのまま残る）→ 再適用しても Netflix は1回だけ。
      t.update_columns(category_id: nil)
      apply

      expect(t.reload.description).to eq(first)
      expect(t.description.scan("Netflix").size).to eq(1)
    end
  end
end

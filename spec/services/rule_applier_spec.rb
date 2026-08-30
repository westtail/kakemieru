require "rails_helper"

RSpec.describe RuleApplier, type: :service do
  let(:user) { create(:user) }
  let(:payment_method) { create(:payment_method, user: user) }
  let(:food) { create(:category, user: user, name: "食費") }
  let(:transport) { create(:category, user: user, name: "交通費") }

  def tx(merchant:, category: nil, date: Date.new(2026, 1, 10))
    create(:transaction, user: user, payment_method: payment_method,
           merchant_name: merchant, category: category, date: date)
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
end

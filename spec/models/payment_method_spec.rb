require "rails_helper"

RSpec.describe PaymentMethod, type: :model do
  describe "バリデーション・関連" do
    subject { build(:payment_method) }

    it "factory が有効" do
      is_expected.to be_valid
    end

    it { is_expected.to belong_to(:user) }
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:payment_type) }

    # scoped_to(:user_id) の一意性は user_id が FK のため shoulda が誤検知する
    # （category_spec / user_spec と同じ事情）。ここは明示テストで担保する。
    it "同一ユーザー内で name 重複はエラー" do
      user = create(:user)
      create(:payment_method, user: user, name: "楽天カード")
      duplicate = build(:payment_method, user: user, name: "楽天カード")
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:name]).to be_present
    end

    it "異なるユーザーなら同名でも OK" do
      create(:payment_method, user: create(:user), name: "楽天カード")
      other = build(:payment_method, user: create(:user), name: "楽天カード")
      expect(other).to be_valid
    end
  end

  describe "payment_type enum" do
    it "5値を持ち、cash? が使える" do
      expect(PaymentMethod.payment_types.keys).to match_array(%w[credit debit e_money qr cash])
      expect(build(:payment_method, :cash).cash?).to be true
      expect(build(:payment_method, payment_type: "credit").cash?).to be false
    end

    it "不正な payment_type はバリデーションエラー（例外ではなく422相当）" do
      pm = build(:payment_method, payment_type: "bitcoin")
      expect(pm).not_to be_valid
      expect(pm.errors[:payment_type]).to be_present
    end
  end

  describe "スコープ" do
    it "active は archived_at NULL、archived はそれ以外" do
      user = create(:user)
      active = create(:payment_method, user: user)
      archived = create(:payment_method, :archived, user: user)

      expect(PaymentMethod.active).to include(active)
      expect(PaymentMethod.active).not_to include(archived)
      expect(PaymentMethod.archived).to include(archived)
      expect(PaymentMethod.archived).not_to include(active)
    end
  end

  describe ".create_default_for" do
    it "現金（cash）を1件生成する" do
      user = create(:user)
      expect { PaymentMethod.create_default_for(user) }.to change { user.payment_methods.count }.by(1)

      cash = user.payment_methods.last
      expect(cash.name).to eq("現金")
      expect(cash.cash?).to be true
    end
  end
end

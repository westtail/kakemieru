require "rails_helper"

RSpec.describe User, type: :model do
  describe "バリデーション" do
    subject { build(:user) }

    it "factory が有効" do
      is_expected.to be_valid
    end

    it { is_expected.to validate_presence_of(:email_address) }

    # shoulda の validate_uniqueness_of は大文字違いの値で検証するため normalizes と
    # 相性が悪い。一意性は下記の明示テストで担保する。
    it "同じメールアドレスは重複として弾く" do
      create(:user, email_address: "dup@example.com")
      duplicate = build(:user, email_address: "dup@example.com")
      expect(duplicate).not_to be_valid
    end

    it "メールアドレスの形式が不正だと無効" do
      user = build(:user, email_address: "not-an-email")
      expect(user).not_to be_valid
      expect(user.errors[:email_address]).to be_present
    end

    it "大文字違いのメールアドレスは重複として弾く（normalizes による実質 case-insensitive）" do
      create(:user, email_address: "dup@example.com")
      duplicate = build(:user, email_address: "DUP@Example.com")
      expect(duplicate).not_to be_valid
    end

    it "パスワードが空だと無効" do
      user = build(:user, password: nil)
      expect(user).not_to be_valid
      expect(user.errors[:password]).to be_present
    end

    it "パスワードが8文字未満だと無効" do
      user = build(:user, password: "short12")
      expect(user).not_to be_valid
      expect(user.errors[:password]).to be_present
    end

    it "パスワードが8文字以上なら有効" do
      user = build(:user, password: "password")
      expect(user).to be_valid
    end
  end

  describe "email_address の正規化" do
    it "前後の空白を除去し小文字化して保存する" do
      user = create(:user, email_address: "  Foo@Example.COM ")
      expect(user.email_address).to eq("foo@example.com")
    end
  end

  describe "has_secure_password" do
    it "正しいパスワードで authenticate に成功する" do
      user = create(:user, password: "secret123")
      expect(user.authenticate("secret123")).to be_truthy
    end

    it "誤ったパスワードで authenticate に失敗する" do
      user = create(:user, password: "secret123")
      expect(user.authenticate("wrong-password")).to be_falsey
    end
  end

  describe "admin フラグ" do
    it "デフォルトは false" do
      expect(create(:user).admin).to be(false)
    end

    it "trait :admin で true になる" do
      expect(create(:user, :admin).admin).to be(true)
    end

    it "作成済みユーザーの通常更新では admin を変更できない（attr_readonly）" do
      user = create(:user)
      # Rails 8（raise_on_assign_to_attr_readonly=true）では readonly 属性への代入は例外。
      expect { user.update!(admin: true) }.to raise_error(ActiveRecord::ReadonlyAttributeError)
      expect(user.reload.admin).to be(false)
    end
  end

  describe "関連" do
    it { is_expected.to have_many(:sessions).dependent(:destroy) }

    it "ユーザーを削除すると紐づくセッションも削除される" do
      user = create(:user)
      user.sessions.create!(ip_address: "127.0.0.1", user_agent: "test-agent")
      expect { user.destroy }.to change(Session, :count).by(-1)
    end
  end
end

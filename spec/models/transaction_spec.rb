require "rails_helper"

RSpec.describe Transaction, type: :model do
  describe "関連・バリデーション" do
    subject { build(:transaction) }

    it "factory が有効" do
      is_expected.to be_valid
    end

    it { is_expected.to belong_to(:user) }
    it { is_expected.to belong_to(:payment_method) }
    it { is_expected.to belong_to(:import).optional }
    it { is_expected.to belong_to(:category).optional }
    it { is_expected.to validate_presence_of(:date) }
    it { is_expected.to validate_presence_of(:amount) }
    it { is_expected.to validate_presence_of(:merchant_name) }

    it "金額は整数でない/小数/桁あふれは無効、0・負値（返金）は有効" do
      expect(build(:transaction, amount: "abc")).not_to be_valid
      expect(build(:transaction, amount: 1200.99)).not_to be_valid
      expect(build(:transaction, amount: 2_147_483_648)).not_to be_valid
      expect(build(:transaction, amount: 0)).to be_valid
      expect(build(:transaction, amount: -500)).to be_valid
    end

    it "merchant_name は255文字超で無効" do
      expect(build(:transaction, merchant_name: "あ" * 256)).not_to be_valid
    end

    it "amount_override は整数・int4範囲（nil可）、date_override は正しい日付（nil可）" do
      expect(build(:transaction, amount_override: "abc")).not_to be_valid
      expect(build(:transaction, amount_override: 2_147_483_648)).not_to be_valid
      expect(build(:transaction, amount_override: nil)).to be_valid
      expect(build(:transaction, amount_override: 800)).to be_valid
      expect(build(:transaction, date_override: "not-a-date")).not_to be_valid
      expect(build(:transaction, date_override: nil)).to be_valid
      expect(build(:transaction, date_override: Date.new(2026, 2, 1))).to be_valid
    end
  end

  describe "原本の不変性（attr_readonly）" do
    it "永続化後に date/amount を更新しようとすると ReadonlyAttributeError" do
      tx = create(:transaction, amount: 1000, date: Date.new(2026, 1, 10))
      expect { tx.update!(amount: 9999) }.to raise_error(ActiveRecord::ReadonlyAttributeError)
      expect { tx.update!(date: Date.new(2026, 2, 1)) }.to raise_error(ActiveRecord::ReadonlyAttributeError)
    end
  end

  describe "テナント整合（import）" do
    it "別ユーザーの import は紐づけられない" do
      other = create(:user)
      others_import = create(:import, user: other, payment_method: create(:payment_method, user: other))
      tx = build(:transaction, import: others_import)
      expect(tx).not_to be_valid
      expect(tx.errors[:import]).to be_present
    end
  end

  describe "生成カラム effective_amount / effective_date" do
    let(:user) { create(:user) }
    let(:payment_method) { create(:payment_method, user: user) }

    it "override が無ければ原本、あれば override を使う（DB 生成カラム）" do
      tx = create(:transaction, user: user, payment_method: payment_method, amount: 1000, date: Date.new(2026, 1, 10))
      expect(tx.reload.effective_amount).to eq(1000)
      expect(tx.effective_date).to eq(Date.new(2026, 1, 10))

      tx.update!(amount_override: 800, date_override: Date.new(2026, 2, 1))
      expect(tx.reload.effective_amount).to eq(800)
      expect(tx.effective_date).to eq(Date.new(2026, 2, 1))
    end
  end

  describe "スコープ" do
    let(:user) { create(:user) }
    let(:payment_method) { create(:payment_method, user: user) }

    it "not_deleted は deleted_at が NULL のもののみ" do
      active = create(:transaction, user: user, payment_method: payment_method)
      deleted = create(:transaction, user: user, payment_method: payment_method, deleted_at: Time.current)
      expect(Transaction.not_deleted).to include(active)
      expect(Transaction.not_deleted).not_to include(deleted)
    end

    it "in_month は effective_date が月内のもののみ（月初・月末・翌月初の境界）" do
      first = create(:transaction, user: user, payment_method: payment_method, date: Date.new(2026, 1, 1))
      last  = create(:transaction, user: user, payment_method: payment_method, date: Date.new(2026, 1, 31))
      next_month = create(:transaction, user: user, payment_method: payment_method, date: Date.new(2026, 2, 1))

      result = Transaction.in_month(2026, 1)
      expect(result).to include(first, last)
      expect(result).not_to include(next_month)
    end

    it "in_month は override 後の effective_date で判定する" do
      tx = create(:transaction, user: user, payment_method: payment_method, date: Date.new(2026, 1, 15))
      tx.update!(date_override: Date.new(2026, 2, 15))
      expect(Transaction.in_month(2026, 1)).not_to include(tx)
      expect(Transaction.in_month(2026, 2)).to include(tx)
    end
  end

  describe "関連削除の挙動（S3-S5 で繰り延べた配線）" do
    let(:user) { create(:user) }
    let(:payment_method) { create(:payment_method, user: user) }

    it "カテゴリを削除すると紐づく明細の category_id が NULL になる（nullify）" do
      category = create(:category, user: user)
      tx = create(:transaction, user: user, payment_method: payment_method, category: category)
      category.destroy
      expect(tx.reload.category_id).to be_nil
    end

    it "明細を持つ支払方法は archivable? が true で archive! でアーカイブできる" do
      create(:transaction, user: user, payment_method: payment_method)
      expect(payment_method.archivable?).to be true
      expect { payment_method.archive! }.to change { payment_method.reload.archived_at }.from(nil)
    end

    it "明細を持つ Import は物理削除できない（restrict）" do
      import = create(:import, user: user, payment_method: payment_method)
      create(:transaction, user: user, payment_method: payment_method, import: import)
      expect { import.destroy }.to raise_error(ActiveRecord::DeleteRestrictionError)
    end
  end

  describe "退会カスケード（明細・取り込みを持つユーザー）" do
    it "明細と取り込みを持つユーザーを destroy しても例外にならず全部消える" do
      user = create(:user)
      payment_method = create(:payment_method, user: user)
      import = create(:import, user: user, payment_method: payment_method)
      create(:transaction, user: user, payment_method: payment_method, import: import)

      expect { user.destroy }.to change(Transaction, :count).by(-1).and change(Import, :count).by(-1)
      expect(user).to be_destroyed
    end
  end
end

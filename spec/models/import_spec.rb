require "rails_helper"

RSpec.describe Import, type: :model do
  describe "関連・バリデーション" do
    subject { build(:import) }

    it "factory が有効" do
      is_expected.to be_valid
    end

    it { is_expected.to belong_to(:user) }
    it { is_expected.to belong_to(:payment_method) }
    it { is_expected.to validate_presence_of(:source_type) }
    it { is_expected.to validate_presence_of(:file_hash) }
  end

  describe "source_type enum" do
    it "4値を持ち、csv? が使える" do
      expect(Import.source_types.keys).to match_array(%w[csv ocr api manual_bulk])
      expect(build(:import, source_type: "csv").csv?).to be true
    end

    it "不正な source_type はバリデーションエラー" do
      import = build(:import, source_type: "xml")
      expect(import).not_to be_valid
      expect(import.errors[:source_type]).to be_present
    end
  end

  describe "source_ref" do
    it "csv では必須" do
      import = build(:import, source_type: "csv", source_ref: nil)
      expect(import).not_to be_valid
      expect(import.errors[:source_ref]).to be_present
    end

    it "manual_bulk では省略できる" do
      import = build(:import, source_type: "manual_bulk", source_ref: nil)
      expect(import).to be_valid
    end
  end

  describe "file_hash の重複防止（user スコープ）" do
    # scoped_to(:user_id) は FK のため shoulda が誤検知するので明示テスト。
    it "同一ユーザーで同じ file_hash は重複エラー（二重取り込み防止）" do
      user = create(:user)
      create(:import, user: user, file_hash: "abc123")
      duplicate = build(:import, user: user, file_hash: "abc123")
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:file_hash]).to be_present
    end

    it "別ユーザーなら同じ file_hash でも OK" do
      create(:import, user: create(:user), file_hash: "abc123")
      other = build(:import, user: create(:user), file_hash: "abc123")
      expect(other).to be_valid
    end
  end
end

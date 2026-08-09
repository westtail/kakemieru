require "rails_helper"

RSpec.describe Category, type: :model do
  describe "バリデーション・関連" do
    it "name が必須" do
      category = build(:category, name: nil)
      expect(category).not_to be_valid
      expect(category.errors[:name]).to be_present
    end

    it "user が必須" do
      category = build(:category, user: nil)
      expect(category).not_to be_valid
      expect(category.errors[:user]).to be_present
    end

    it "同一ユーザー内で name 重複はエラー" do
      user = create(:user)
      create(:category, user: user, name: "食費")
      duplicate = build(:category, user: user, name: "食費")
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:name]).to be_present
    end

    it "異なるユーザーなら同名でも OK" do
      create(:category, user: create(:user), name: "食費")
      other = build(:category, user: create(:user), name: "食費")
      expect(other).to be_valid
    end
  end

  describe "初期/独自の区別" do
    it "category_key ありは初期カテゴリ（initial? = true・initial スコープに含まれる）" do
      user = create(:user)
      initial = create(:category, :initial, user: user)
      custom = create(:category, user: user)

      expect(initial.initial?).to be true
      expect(custom.initial?).to be false
      expect(Category.initial).to include(initial)
      expect(Category.initial).not_to include(custom)
      expect(Category.custom).to include(custom)
      expect(Category.custom).not_to include(initial)
    end
  end

  describe ".copy_templates_to" do
    it "テンプレート全件を当該ユーザーのカテゴリとしてコピーする（key/name 一致）" do
      CategoryCatalog::DEFAULTS.each { |c| CategoryTemplate.create!(category_key: c[:key], name: c[:name]) }
      user = create(:user)

      expect { Category.copy_templates_to(user) }
        .to change { user.categories.count }.from(0).to(CategoryCatalog::DEFAULTS.size)

      copied = user.categories.order(:id).pluck(:category_key, :name)
      template = CategoryTemplate.order(:id).pluck(:category_key, :name)
      expect(copied).to eq(template)
    end

    it "コピーされたカテゴリはすべて初期カテゴリ（category_key あり）" do
      CategoryTemplate.create!(category_key: "food", name: "食費")
      user = create(:user)
      Category.copy_templates_to(user)
      expect(user.categories.all?(&:initial?)).to be true
    end
  end
end

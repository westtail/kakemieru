require "rails_helper"

RSpec.describe CategoryTemplate, type: :model do
  it "category_key と name が必須" do
    template = CategoryTemplate.new
    expect(template).not_to be_valid
    expect(template.errors[:category_key]).to be_present
    expect(template.errors[:name]).to be_present
  end

  it "category_key は一意" do
    create(:category_template, category_key: "food")
    duplicate = build(:category_template, category_key: "food")
    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:category_key]).to be_present
  end
end

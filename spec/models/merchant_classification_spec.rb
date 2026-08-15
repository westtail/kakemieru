require "rails_helper"

RSpec.describe MerchantClassification, type: :model do
  subject { build(:merchant_classification) }

  it "factory が有効" do
    is_expected.to be_valid
  end

  it { is_expected.to validate_presence_of(:merchant_name) }
  it { is_expected.to validate_presence_of(:category_key) }
  it { is_expected.to validate_presence_of(:source) }
  it { is_expected.to validate_inclusion_of(:source).in_array(%w[ai user_manual]) }

  it "merchant_name は一意（全ユーザー共通）" do
    create(:merchant_classification, merchant_name: "Amazon")
    duplicate = build(:merchant_classification, merchant_name: "Amazon")
    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:merchant_name]).to be_present
  end
end

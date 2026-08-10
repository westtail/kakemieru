require "rails_helper"

RSpec.describe CategoryTemplate, type: :model do
  subject { build(:category_template) }

  it "factory が有効" do
    is_expected.to be_valid
  end

  it { is_expected.to validate_presence_of(:category_key) }
  it { is_expected.to validate_presence_of(:name) }
  it { is_expected.to validate_uniqueness_of(:category_key) }
end

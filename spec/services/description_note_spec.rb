require "rails_helper"

RSpec.describe DescriptionNote do
  describe ".append" do
    it "空の説明には note だけを返す" do
      expect(described_class.append(nil, "Netflix")).to eq("Netflix")
      expect(described_class.append("", "Netflix")).to eq("Netflix")
    end

    it "既存の説明に「 / 」区切りで追記する" do
      expect(described_class.append("楽天SP", "Netflix")).to eq("楽天SP / Netflix")
    end

    it "note が空なら説明をそのまま返す" do
      expect(described_class.append("楽天SP", nil)).to eq("楽天SP")
      expect(described_class.append("楽天SP", "")).to eq("楽天SP")
    end

    it "既に同じ note を含む説明には追記しない（冪等）" do
      expect(described_class.append("楽天SP / Netflix", "Netflix")).to eq("楽天SP / Netflix")
    end
  end
end

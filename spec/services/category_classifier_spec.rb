require "rails_helper"

RSpec.describe CategoryClassifier do
  describe ".normalize" do
    it "NFKC + 前後空白除去 + 小文字化で照合キーを揃える" do
      expect(CategoryClassifier.normalize(" Ａｍａｚｏｎ ")).to eq("amazon")
      expect(CategoryClassifier.normalize("amazon")).to eq("amazon")
      expect(CategoryClassifier.normalize("AMAZON")).to eq("amazon")
    end

    it "空・nil は空文字を返す" do
      expect(CategoryClassifier.normalize(nil)).to eq("")
      expect(CategoryClassifier.normalize("   ")).to eq("")
    end
  end
end

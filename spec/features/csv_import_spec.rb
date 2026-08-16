require "rails_helper"

RSpec.describe "CSVインポート", type: :feature do
  let(:csv_path) { Rails.root.join("spec/fixtures/files/rakuten_sample.csv") }

  it "楽天CSVをアップロードすると明細が取り込まれ一覧に表示される" do
    user = create(:user)
    create(:payment_method, user: user, name: "楽天カード")
    sign_in_as(user)

    visit new_import_path
    select "楽天カード", from: "支払方法"
    attach_file "CSVファイル（楽天カード・Shift-JIS）", csv_path
    click_button "取り込む"

    # 取り込んだ月の一覧へ遷移し、CSV の明細が表示される
    expect(page).to have_content("ローソン")
    expect(page).to have_content("Amazon")
    expect(page).to have_content("スターバックス")
    expect(user.transactions.count).to eq(3)
  end
end

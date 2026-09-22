require "rails_helper"

RSpec.describe "ランディングページ", type: :feature do
  it "未ログインで / を訪れるとLPが表示され、新規登録へ遷移できる" do
    visit "/"

    expect(page).to have_content("家計を、見える化。")
    expect(page).to have_link("ログイン", href: new_session_path)

    first(:link, "無料で始める").click
    expect(page).to have_current_path(new_registration_path)
  end
end

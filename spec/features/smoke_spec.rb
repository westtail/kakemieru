require "rails_helper"

# E2E パイプライン（Capybara → Chrome コンテナ → web → レスポンス）の疎通確認。
# 認証導入後は "/" が保護されるため、公開されているログイン画面で疎通を確認する。
# 認証済みフローの検証は authentication_spec が担当する。
RSpec.describe "Smoke", type: :feature do
  it "ログイン画面を実ブラウザで表示できる" do
    visit "/sign_in"
    expect(page).to have_content("ログイン")
  end
end

require "test_helper"

class HomeControllerTest < ActionDispatch::IntegrationTest
  test "GET / returns 200" do
    get root_path
    assert_response :success
  end

  test "GET / displays app title" do
    get root_path
    assert_select "h1", "掛け見える - 家計簿アプリ"
  end

  test "GET / shows running status" do
    get root_path
    assert_select "p", /アプリケーション稼働中/
  end

  test "GET /home/index returns 200" do
    get home_index_path
    assert_response :success
  end
end

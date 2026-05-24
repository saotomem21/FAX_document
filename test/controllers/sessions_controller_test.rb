require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @company = Company.create!(name: "株式会社テスト")
    @user = User.create!(
      company: @company,
      name: "山田 太郎",
      email: "user@example.com",
      password: "password",
      password_confirmation: "password"
    )
  end

  test "logs in with valid credentials" do
    post login_path, params: { email: @user.email, password: "password" }

    assert_redirected_to manuscripts_path
    follow_redirect!
    assert_select "h1", "原稿一覧"
  end

  test "rejects invalid credentials" do
    post login_path, params: { email: @user.email, password: "wrong" }

    assert_response :unprocessable_entity
    assert_select ".flash-message.alert"
  end
end

require "rails_helper"

RSpec.feature "Manuscript creation", type: :feature do
  let!(:company) { Company.create!(name: "株式会社テスト") }
  let!(:user) do
    User.create!(
      company: company,
      name: "テストユーザー",
      email: "user@example.com",
      password: "password",
      password_confirmation: "password"
    )
  end

  scenario "user logs in and sees validation errors on manuscript creation" do
    visit login_path

    fill_in "メールアドレス", with: user.email
    fill_in "パスワード", with: "password"
    click_button "ログイン"

    expect(page).to have_current_path(manuscripts_path)

    visit new_manuscript_path

    click_button "生成開始"

    expect(page).to have_content("入力内容を確認してください。")
    expect(page).to have_content("原稿タイトルを入力してください")
    expect(page).to have_content("サービス名を入力してください")
    expect(page).to have_content("サービス概要を入力してください")
    expect(page).to have_content("ターゲットを入力してください")
    expect(page).to have_content("FAXDMの目的を入力してください")
    expect(page).to have_content("問い合わせ導線を入力してください")
  end
end

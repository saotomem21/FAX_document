require "test_helper"

class ManuscriptGenerationServiceTest < ActiveSupport::TestCase
  test "generates body, svg, pdf, and version" do
    company = Company.create!(name: "株式会社テスト")
    user = User.create!(
      company: company,
      name: "担当者",
      email: "service@example.com",
      password: "password",
      password_confirmation: "password"
    )
    manuscript = company.manuscripts.create!(
      user: user,
      title: "採用支援DM",
      service_name: "採用支援サービス",
      service_summary: "求人票作成から応募者対応まで支援します。",
      target: "人事担当者",
      purpose: "資料請求の獲得",
      contact_methods: "FAX返信"
    )

    ManuscriptGenerationService.new(manuscript).generate!

    manuscript.reload
    assert_equal "generated", manuscript.status
    assert_equal 1, manuscript.manuscript_versions.count
    assert File.exist?(Rails.root.join(manuscript.generated_svg_path))
    assert File.exist?(Rails.root.join(manuscript.generated_pdf_path))
  end
end

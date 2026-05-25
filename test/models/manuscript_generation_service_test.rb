require "test_helper"

class ManuscriptGenerationServiceTest < ActiveSupport::TestCase
  test "generates prompt, then pdf" do
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

    # Step 1: Generate prompt
    Ai::FaxPromptGenerator.new(manuscript).generate!
    manuscript.reload
    assert_includes %w[prompt_generated prompt_generating], manuscript.status
    assert manuscript.generated_structure.present?

    # Step 2: Generate PDF
    ManuscriptGenerationService.new(manuscript).generate_pdf!

    manuscript.reload
    assert_equal "generated", manuscript.status
    assert_equal 1, manuscript.manuscript_versions.count
    assert File.exist?(Rails.root.join(manuscript.generated_pdf_path))
  end

  test "marks failed status on error" do
    company = Company.create!(name: "株式会社テスト")
    user = User.create!(
      company: company,
      name: "担当者",
      email: "fail@example.com",
      password: "password",
      password_confirmation: "password"
    )
    manuscript = company.manuscripts.create!(
      user: user,
      title: "失敗テストDM",
      service_name: "テストサービス",
      service_summary: "テスト",
      target: "テスト",
      purpose: "テスト",
      contact_methods: "テスト",
      generated_body: "test body",
      generated_structure: { "headline" => "テスト" },
      status: "prompt_generated"
    )

    # Mock PDF generation to fail
    Pdf::FaxPrawnRenderer.stubs(:render).raises(StandardError, "mock failure")

    assert_raises(StandardError) do
      ManuscriptGenerationService.new(manuscript).generate_pdf!
    end

    manuscript.reload
    assert_equal "failed", manuscript.status
  end
end
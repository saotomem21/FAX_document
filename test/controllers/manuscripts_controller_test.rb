require "test_helper"

class ManuscriptsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @company = Company.create!(name: "株式会社テスト", monthly_generation_limit: 500)
    @user = User.create!(
      company: @company,
      name: "佐藤 花子",
      department: "営業企画部",
      email: "planner@example.com",
      password: "password",
      password_confirmation: "password"
    )
    post login_path, params: { email: @user.email, password: "password" }
  end

  test "creates and generates manuscript" do
    assert_difference -> { Manuscript.count }, 1 do
      post manuscripts_path, params: {
        commit_action: "generate",
        manuscript: manuscript_params
      }
    end

    manuscript = Manuscript.order(:created_at).last
    assert_redirected_to manuscript_path(manuscript)
    assert_equal "generated", manuscript.status
    assert manuscript.generated_body.present?
    assert manuscript.generated_svg_path.present?
    assert manuscript.generated_pdf_path.present?
    assert_equal 1, manuscript.manuscript_versions.count
  end

  test "downloads pdf and regenerates with instruction" do
    manuscript = @company.manuscripts.create!(manuscript_params.merge(user: @user, status: "draft"))
    ManuscriptGenerationService.new(manuscript).generate!

    get pdf_manuscript_path(manuscript)
    assert_response :success
    assert_equal "application/pdf", response.media_type

    assert_difference -> { manuscript.manuscript_versions.count }, 1 do
      post regenerate_manuscript_path(manuscript), params: { edit_instruction: "緊急感を強めてください" }
    end

    assert_redirected_to manuscript_path(manuscript)
  end

  test "uses template to prefill new manuscript form" do
    template = @company.templates.create!(manuscript_params.merge(user: @user, title: "営業支援テンプレート"))

    get new_manuscript_path(template_id: template.id)

    assert_response :success
    assert_select "input[value='#{template.service_name}']"
  end

  private

  def manuscript_params
    {
      title: "足場工事向けDM",
      company_name: "株式会社テスト",
      service_name: "足場工事サービス",
      service_summary: "足場工事と仮設機材の手配をまとめて支援します。",
      target_region: "関東",
      target: "工務店のご担当者様",
      purpose: "新規問い合わせ獲得",
      contact_methods: "電話・FAX返信",
      catch_copy: "急な足場手配でお困りの方へ！",
      strengths: "迅速対応、地域密着、安全管理",
      urgency_reason: "繁忙期前に早めのご相談をおすすめします。",
      phone_number: "03-1111-2222",
      fax_number: "03-1111-2223",
      website_url: "https://example.jp",
      reception_hours: "平日 9:00〜18:00"
    }
  end
end

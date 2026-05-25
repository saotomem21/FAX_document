class ManuscriptsController < ApplicationController
  before_action :require_login
  before_action :set_manuscript, only: %i[show edit update destroy
    generate_prompt regenerate_prompt generate_pdf generate_image
    duplicate prompt update_prompt pdf preview_image]

  def index
    @manuscripts = current_company.manuscripts.latest_first
    @manuscripts = @manuscripts.where(status: params[:status]) if params[:status].present?
    @manuscripts = filter_by_query(@manuscripts, params[:q]) if params[:q].present?
    @templates = current_company.templates.latest_first.limit(3)
  end

  def show
    @versions = @manuscript.manuscript_versions.order(version_number: :desc)
  end

  def new
    @manuscript = current_company.manuscripts.new(user: current_user, status: "draft")
    if params[:template_id].present?
      template = current_company.templates.find(params[:template_id])
      @manuscript.assign_template(template)
    end
  end

  def create
    @manuscript = current_company.manuscripts.new(manuscript_params)
    @manuscript.user = current_user
    @manuscript.status = "draft"

    if @manuscript.save
      save_template_from(@manuscript) if params[:save_as_template] == "1"
      generate_prompt_and_redirect(@manuscript)
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @manuscript.update(manuscript_params)
      save_template_from(@manuscript) if params[:save_as_template] == "1"
      generate_prompt_and_redirect(@manuscript)
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # GET /manuscripts/:id/prompt - 原稿構成確認画面
  def prompt
    unless @manuscript.prompt_generated? || @manuscript.can_generate_prompt?
      redirect_to @manuscript, alert: "構成確認画面を表示できません。先にフォーム入力から構成を生成してください。"
    end
    @structure = @manuscript.generated_structure
    @structure = JSON.parse(@structure) if @structure.is_a?(String)
    # Backward compat: detect old format and suggest regeneration
    @needs_regeneration = @structure.present? && (@structure["target_label"].nil? && @structure["problem_points"].nil?)
  end

  # POST /manuscripts/:id/generate_prompt - generate structure from form inputs
  def generate_prompt
    begin
      Ai::FaxPromptGenerator.new(@manuscript).generate!
      redirect_to prompt_manuscript_path(@manuscript), notice: "原稿構成を生成しました。内容を確認してください。"
    rescue => e
      Rails.logger.error "Structure generation failed: #{e.message}"
      redirect_to @manuscript, alert: "構成生成に失敗しました。もう一度お試しください。"
    end
  end

  # PATCH /manuscripts/:id/update_prompt - save user edits (no-op as structure is stored differently)
  def update_prompt
    redirect_to prompt_manuscript_path(@manuscript), notice: "構成を保存しました。"
  end

  # POST /manuscripts/:id/regenerate_prompt - regenerate structure from form inputs
  def regenerate_prompt
    begin
      Ai::FaxPromptGenerator.new(@manuscript).generate!
      redirect_to prompt_manuscript_path(@manuscript), notice: "原稿構成を再生成しました。内容を確認してください。"
    rescue => e
      Rails.logger.error "Structure regeneration failed: #{e.message}"
      redirect_to prompt_manuscript_path(@manuscript), alert: "構成再生成に失敗しました。もう一度お試しください。"
    end
  end

  # POST /manuscripts/:id/generate_pdf - generate PDF from structure
  def generate_pdf
    unless @manuscript.prompt_generated? && @manuscript.generated_structure.present?
      redirect_to prompt_manuscript_path(@manuscript), alert: "先に原稿構成を生成・確認してください。"
      return
    end

    begin
      ManuscriptGenerationService.new(@manuscript).generate_pdf!
      redirect_to @manuscript, notice: "FAX原稿PDFを生成しました。"
    rescue => e
      Rails.logger.error "PDF generation failed: #{e.message}"
      redirect_to @manuscript, alert: "原稿生成に失敗しました。もう一度お試しください。"
    end
  end

  # Keep generate_image for backward compatibility, delegates to generate_pdf
  def generate_image
    generate_pdf
  end

  def duplicate
    copy = current_company.manuscripts.new(@manuscript.form_attributes)
    copy.user = current_user
    copy.title = "#{@manuscript.title} の複製"
    copy.status = "draft"
    copy.save!
    redirect_to edit_manuscript_path(copy), notice: "原稿を複製しました。"
  end

  def destroy
    @manuscript.destroy
    redirect_to manuscripts_path, notice: "原稿を削除しました。"
  end

  # GET /manuscripts/:id/preview_image - serve PDF as inline preview
  def preview_image
    if @manuscript.generated_pdf_path.blank? && @manuscript.generated_structure.present?
      ManuscriptGenerationService.new(@manuscript).generate_pdf!
    end
    path = Rails.root.join(@manuscript.generated_pdf_path.to_s)
    return head :not_found unless path.exist?

    send_file path, type: "application/pdf", disposition: "inline"
  end

  def pdf
    if @manuscript.generated_pdf_path.blank? && @manuscript.generated_structure.present?
      ManuscriptGenerationService.new(@manuscript).generate_pdf!
    end
    path = Rails.root.join(@manuscript.generated_pdf_path.to_s)
    return redirect_to(@manuscript, alert: "PDFを生成できませんでした。") unless path.exist?

    send_file path,
      filename: "#{@manuscript.title.parameterize.presence || "fax-manuscript"}.pdf",
      type: "application/pdf",
      disposition: "attachment"
  end

  private

  def set_manuscript
    @manuscript = current_company.manuscripts.find(params[:id])
  end

  def manuscript_params
    params.require(:manuscript).permit(
      :title, :company_name, :service_name, :service_summary, :target_region,
      :target, :purpose, :contact_methods, :catch_copy, :strengths,
      :urgency_reason, :phone_number, :fax_number, :email, :website_url,
      :reception_hours, :address, :credibility, :opt_out_notice
    )
  end

  def filter_by_query(scope, query)
    like = "%#{ActiveRecord::Base.sanitize_sql_like(query)}%"
    scope.where(
      "title LIKE :q OR service_name LIKE :q OR target LIKE :q",
      q: like
    )
  end

  def generate_prompt_and_redirect(manuscript)
    if params[:commit_action] == "generate"
      begin
        Ai::FaxPromptGenerator.new(manuscript).generate!
        redirect_to prompt_manuscript_path(manuscript), notice: "プロンプトを生成しました。内容を確認してください。"
      rescue => e
        Rails.logger.error "Prompt generation failed: #{e.message}"
        redirect_to manuscript, alert: "プロンプト生成に失敗しました。下書きとして保存しました。"
      end
    else
      redirect_to manuscript, notice: "下書きを保存しました。"
    end
  end

  def save_template_from(manuscript)
    current_company.templates.create!(
      manuscript.form_attributes.merge(
        user: current_user,
        title: params[:template_title].presence || Time.current.strftime("%Y/%m/%d/%H/%M/%S"),
        description: "#{manuscript.target}向け / #{manuscript.purpose}"
      )
    )
  end
end
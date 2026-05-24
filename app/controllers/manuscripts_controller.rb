class ManuscriptsController < ApplicationController
  before_action :require_login
  before_action :set_manuscript, only: %i[show edit update destroy generate regenerate duplicate preview_image pdf]

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
      generate_and_redirect(@manuscript)
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @manuscript.update(manuscript_params)
      save_template_from(@manuscript) if params[:save_as_template] == "1"
      generate_and_redirect(@manuscript)
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def generate
    ManuscriptGenerationService.new(@manuscript).generate!
    redirect_to @manuscript, notice: "原稿を生成しました。"
  end

  def regenerate
    ManuscriptGenerationService.new(@manuscript, edit_instruction: params[:edit_instruction]).generate!
    redirect_to @manuscript, notice: "編集指示を反映して再生成しました。"
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

  def preview_image
    ManuscriptGenerationService.new(@manuscript).generate! if @manuscript.generated_svg_path.blank?
    path = Rails.root.join(@manuscript.generated_svg_path)
    return head :not_found unless path.exist?

    send_file path, type: "image/svg+xml", disposition: "inline"
  end

  def pdf
    ManuscriptGenerationService.new(@manuscript).generate! if @manuscript.generated_pdf_path.blank?
    path = Rails.root.join(@manuscript.generated_pdf_path)
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

  def generate_and_redirect(manuscript)
    if params[:commit_action] == "generate"
      ManuscriptGenerationService.new(manuscript).generate!
      redirect_to manuscript, notice: "原稿を生成しました。"
    else
      redirect_to manuscript, notice: "下書きを保存しました。"
    end
  end

  def save_template_from(manuscript)
    current_company.templates.create!(
      manuscript.form_attributes.merge(
        user: current_user,
        title: params[:template_title].presence || "#{manuscript.service_name}テンプレート",
        description: "#{manuscript.target}向け / #{manuscript.purpose}"
      )
    )
  end
end

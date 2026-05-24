class TemplatesController < ApplicationController
  before_action :require_login
  before_action :set_template, only: %i[edit update destroy]

  def index
    @templates = current_company.templates.latest_first
    @templates = filter_by_query(@templates, params[:q]) if params[:q].present?
  end

  def new
    @template = current_company.templates.new(user: current_user)
  end

  def create
    @template = current_company.templates.new(template_params)
    @template.user = current_user

    if @template.save
      redirect_to templates_path, notice: "テンプレートを保存しました。"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @template.update(template_params)
      redirect_to templates_path, notice: "テンプレートを更新しました。"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @template.destroy
    redirect_to templates_path, notice: "テンプレートを削除しました。"
  end

  private

  def set_template
    @template = current_company.templates.find(params[:id])
  end

  def template_params
    params.require(:template).permit(
      :title, :description, :company_name, :service_name, :service_summary,
      :target_region, :target, :purpose, :contact_methods, :catch_copy,
      :strengths, :urgency_reason, :phone_number, :fax_number, :email,
      :website_url, :reception_hours, :address, :credibility, :opt_out_notice
    )
  end

  def filter_by_query(scope, query)
    like = "%#{ActiveRecord::Base.sanitize_sql_like(query)}%"
    scope.where(
      "title LIKE :q OR service_name LIKE :q OR target LIKE :q",
      q: like
    )
  end
end

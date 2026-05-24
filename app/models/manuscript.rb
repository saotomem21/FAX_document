class Manuscript < ApplicationRecord
  FORM_FIELDS = %i[
    company_name service_name service_summary target_region target purpose
    contact_methods catch_copy strengths urgency_reason phone_number fax_number
    email website_url reception_hours address credibility opt_out_notice
  ].freeze

  STATUS_LABELS = {
    "draft" => "下書き",
    "reviewing" => "レビュー中",
    "generated" => "生成完了"
  }.freeze

  belongs_to :company
  belongs_to :user
  belongs_to :template, optional: true
  has_many :manuscript_versions, dependent: :destroy

  before_validation :set_default_title

  validates :title, :service_name, :service_summary, :target, :purpose, :contact_methods, presence: true
  validates :status, inclusion: { in: STATUS_LABELS.keys }

  scope :latest_first, -> { order(updated_at: :desc) }

  def status_label
    STATUS_LABELS.fetch(status, status)
  end

  def generated?
    status == "generated"
  end

  def display_company_name
    company_name.presence || company.name
  end

  def form_attributes
    FORM_FIELDS.index_with { |field| public_send(field) }
  end

  def assign_template(template)
    self.template = template
    FORM_FIELDS.each { |field| public_send("#{field}=", template.public_send(field)) }
    self.title ||= "#{template.service_name}のご案内"
  end

  def next_version_number
    manuscript_versions.maximum(:version_number).to_i + 1
  end

  private

  def set_default_title
    self.title = "#{service_name}のご案内" if title.blank? && service_name.present?
  end
end

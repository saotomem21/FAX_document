class Template < ApplicationRecord
  belongs_to :company
  belongs_to :user
  has_many :manuscripts, dependent: :nullify

  before_validation :set_default_title

  validates :title, :service_name, :service_summary, :target, :purpose, :contact_methods, presence: true

  scope :latest_first, -> { order(updated_at: :desc) }

  def apply_to(manuscript)
    manuscript.assign_template(self)
  end

  private

  def set_default_title
    self.title = "#{service_name}向けテンプレート" if title.blank? && service_name.present?
  end
end

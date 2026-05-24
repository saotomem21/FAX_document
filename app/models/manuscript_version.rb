class ManuscriptVersion < ApplicationRecord
  belongs_to :manuscript

  validates :version_number, :generated_body, presence: true
  validates :version_number, uniqueness: { scope: :manuscript_id }
end

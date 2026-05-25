class User < ApplicationRecord
  belongs_to :company
  has_many :manuscripts, dependent: :destroy
  has_many :templates, dependent: :destroy

  has_secure_password

  validates :name, :email, presence: true
  validates :email, uniqueness: true
end

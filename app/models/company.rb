class Company < ApplicationRecord
  has_many :users, dependent: :destroy
  has_many :manuscripts, dependent: :destroy
  has_many :templates, dependent: :destroy

  validates :name, presence: true

  def remaining_generations
    monthly_generation_limit - monthly_generation_count
  end
end

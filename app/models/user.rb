class User < ApplicationRecord
  has_secure_password

  has_many :baskets, dependent: :destroy
  has_many :recipes, through: :baskets

  validates :email, presence: true, uniqueness: true

  def in_basket?(recipe)
    baskets.exists?(recipe: recipe)
  end
end

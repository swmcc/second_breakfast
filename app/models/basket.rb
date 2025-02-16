class Basket < ApplicationRecord
    belongs_to :user
    belongs_to :recipe
  
    validates :recipe, uniqueness: { scope: :user, message: "is already in your basket" }
  
    attribute :chosen, :boolean, default: false
  end
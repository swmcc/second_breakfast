# A user's personal bookmark of a recipe.
#
# Deliberately distinct from Basket: a Basket entry is a *shopping* selection —
# it feeds the aggregated ingredients list and the meal plan picker. A Favorite
# is a durable "I like this" bookmark with no effect on shopping lists or meal
# plans.
class Favorite < ApplicationRecord
  belongs_to :user
  belongs_to :recipe

  validates :user_id, uniqueness: { scope: :recipe_id, message: "has already favorited this recipe" }

  scope :newest_first, -> { order(created_at: :desc) }
end

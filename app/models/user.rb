class User < ApplicationRecord
  has_secure_password

  has_many :baskets, dependent: :destroy
  has_many :recipes, through: :baskets
  has_many :api_keys, dependent: :destroy
  has_many :meal_plans, dependent: :destroy

  # Recipes this user authored. Nullified rather than destroyed on account
  # deletion so shared/public recipes outlive their author.
  has_many :owned_recipes, class_name: "Recipe", foreign_key: :user_id, inverse_of: :user, dependent: :nullify

  has_many :ratings, dependent: :destroy
  has_many :reviews, dependent: :destroy
  has_many :favorites, dependent: :destroy
  has_many :favorite_recipes, through: :favorites, source: :recipe

  validates :email, presence: true, uniqueness: true

  def in_basket?(recipe)
    baskets.exists?(recipe: recipe)
  end

  def favorited?(recipe)
    return false if recipe.blank?

    favorites.exists?(recipe_id: recipe.id)
  end

  def aggregated_ingredients
    db_adapter = ActiveRecord::Base.connection.adapter_name.downcase

    if db_adapter.include?("sqlite")
      recipes.joins("JOIN json_each(recipes.ingredients) AS ingredient")
             .select("ingredient.value ->> '$.name' AS name,
                      SUM(CAST(ingredient.value ->> '$.quantity' AS NUMERIC)) AS total_quantity,
                      ingredient.value ->> '$.unit' AS unit")
             .group("name, unit")
             .map { |record| { name: record.name, quantity: record.total_quantity.to_f, unit: record.unit } }
    else
      recipes.joins("CROSS JOIN LATERAL jsonb_array_elements(recipes.ingredients::jsonb) AS ingredient")
             .select("ingredient->>'name' AS name,
                      SUM((ingredient->>'quantity')::NUMERIC) AS total_quantity,
                      ingredient->>'unit' AS unit")
             .group("ingredient->>'name', ingredient->>'unit'")
             .map { |record| { name: record.name, quantity: record.total_quantity.to_f, unit: record.unit } }
    end
  end

  def ingredients_list
    baskets.includes(:recipe).map do |basket|
      {
        recipe_name: basket.recipe.title,
        ingredients: basket.recipe.ingredients
      }
    end
  end
end

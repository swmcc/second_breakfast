class User < ApplicationRecord
  has_secure_password

  has_many :baskets, dependent: :destroy
  has_many :recipes, through: :baskets

  validates :email, presence: true, uniqueness: true

  def in_basket?(recipe)
    baskets.exists?(recipe: recipe)
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

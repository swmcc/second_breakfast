# app/controllers/meals_controller.rb
class MealsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_recipe, only: [ :toggle, :destroy ]

  def index
    @baskets = current_user.baskets.includes(recipe: { image_attachment: :blob })
    @aggregated_ingredients = current_user.aggregated_ingredients
  end

  def destroy
    basket = find_basket
    basket&.destroy
    redirect_to meals_path, notice: "Recipe removed from your saved recipes!"
  end

  def toggle
    basket = find_basket
    if basket
      basket.destroy
      flash_message = "Recipe removed from your saved recipes!"
    else
      current_user.baskets.create(recipe: @recipe)
      flash_message = "Recipe saved!"
    end

    redirect_back fallback_location: recipes_path, notice: flash_message
  end

  private

  def set_recipe
    @recipe = Recipe.find(params[:recipe_id])
  rescue ActiveRecord::RecordNotFound
    redirect_to recipes_path, alert: "Recipe not found"
  end

  def find_basket
    current_user.baskets.find_by(recipe: @recipe)
  end
end

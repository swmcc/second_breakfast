# app/controllers/baskets_controller.rb
class BasketsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_recipe

  def create
    current_user.baskets.create(recipe: @recipe)
    redirect_to recipes_path, notice: "Recipe added to your basket!"
  end

  def destroy
    basket = find_basket
    basket&.destroy
    redirect_to recipes_path, notice: "Recipe removed from your basket!"
  end

  def toggle
    basket = find_basket
    if basket
      basket.destroy
      flash_message = "Recipe removed from your basket!"
    else
      current_user.baskets.create(recipe: @recipe)
      flash_message = "Recipe added to your basket!"
    end

    redirect_to recipes_path, notice: flash_message
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

# app/controllers/baskets_controller.rb
class BasketsController < ApplicationController
    before_action :authenticate_user!
  
    def create
      @recipe = Recipe.find(params[:recipe_id])
      current_user.baskets.create(recipe: @recipe)
      redirect_to recipes_path, notice: "Recipe added to your basket!"
    end
  
    def destroy
      @recipe = Recipe.find(params[:recipe_id])
      basket = current_user.baskets.find_by(recipe: @recipe)
      basket.destroy if basket
      redirect_to recipes_path, notice: "Recipe removed from your basket!"
    end
  
    def toggle
      @recipe = Recipe.find(params[:recipe_id])
      basket = current_user.baskets.find_by(recipe: @recipe)
  
      if basket
        basket.destroy
      else
        current_user.baskets.create(recipe: @recipe)
      end
  
      redirect_to recipes_path
    end
  end
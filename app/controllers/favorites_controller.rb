class FavoritesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_recipe, only: [ :create, :destroy ]

  # GET /favorites
  def index
    @recipes = current_user.favorite_recipes
                           .visible_to(current_user)
                           .includes(:category, image_attachment: :blob)
                           .order("favorites.created_at DESC")
  end

  # POST /recipes/:recipe_id/favorite
  def create
    current_user.favorites.find_or_create_by!(recipe: @recipe)

    redirect_back fallback_location: @recipe, notice: "Added to your favorites."
  end

  # DELETE /recipes/:recipe_id/favorite
  def destroy
    current_user.favorites.find_by(recipe_id: @recipe.id)&.destroy

    redirect_back fallback_location: @recipe, status: :see_other, notice: "Removed from your favorites."
  end

  private

  # You can only favorite a recipe you are allowed to see.
  def set_recipe
    @recipe = Recipe.visible_to(current_user).find(params[:recipe_id])
  end
end

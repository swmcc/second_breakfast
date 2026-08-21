class RatingsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_recipe

  # POST /recipes/:recipe_id/rating
  def create
    rating = current_user.ratings.find_or_initialize_by(recipe: @recipe)
    rating.value = params.dig(:rating, :value)

    if rating.save
      redirect_to @recipe, notice: "Thanks — your rating was saved."
    else
      redirect_to @recipe, alert: rating.errors.full_messages.to_sentence
    end
  end

  # DELETE /recipes/:recipe_id/rating
  def destroy
    current_user.ratings.find_by(recipe_id: @recipe.id)&.destroy

    redirect_to @recipe, status: :see_other, notice: "Your rating was removed."
  end

  private

  # You can only rate a recipe you are allowed to see.
  def set_recipe
    @recipe = Recipe.visible_to(current_user).find(params[:recipe_id])
  end
end

class ReviewsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_recipe
  before_action :set_own_review, only: [ :edit, :update, :destroy ]

  # POST /recipes/:recipe_id/reviews
  def create
    @review = @recipe.reviews.build(review_params)
    @review.user = current_user

    if @review.save
      redirect_to @recipe, notice: "Your review was posted."
    else
      redirect_to @recipe, alert: @review.errors.full_messages.to_sentence
    end
  end

  # GET /recipes/:recipe_id/reviews/:id/edit
  def edit
  end

  # PATCH /recipes/:recipe_id/reviews/:id
  def update
    if @review.update(review_params)
      redirect_to @recipe, notice: "Your review was updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # DELETE /recipes/:recipe_id/reviews/:id
  def destroy
    @review.destroy!

    redirect_to @recipe, status: :see_other, notice: "Your review was deleted."
  end

  private

  # You can only review a recipe you are allowed to see.
  def set_recipe
    @recipe = Recipe.visible_to(current_user).find(params[:recipe_id])
  end

  # Scoping to the current user is the authorization: another user's review is
  # simply not found.
  def set_own_review
    @review = @recipe.reviews.where(user_id: current_user.id).find(params[:id])
  end

  def review_params
    params.require(:review).permit(:body)
  end
end

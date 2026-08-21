class RecipesController < ApplicationController
  # Included here rather than in ApplicationController: only the recipe list
  # and search need a paginated backend.
  include Pagy::Backend

  before_action :authenticate_user!, only: [ :new, :create, :edit, :update, :destroy ]
  before_action :set_recipe, only: %i[ show edit update destroy ]

  # GET /recipes or /recipes.json
  def index
    @pagy, @recipes = paginate_recipes(Recipe.all)
  end

  # GET /recipes/1 or /recipes/1.json
  def show
  end

  # GET /recipes/new
  def new
    @recipe = Recipe.new
  end

  # GET /recipes/1/edit
  def edit
  end

  # POST /recipes or /recipes.json
  def create
    @recipe = Recipe.new(recipe_params)

    respond_to do |format|
      if @recipe.save
        format.html { redirect_to @recipe, notice: "Recipe was successfully created." }
        format.json { render :show, status: :created, location: @recipe }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @recipe.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /recipes/1 or /recipes/1.json
  def update
    respond_to do |format|
      if @recipe.update(recipe_params)
        format.html { redirect_to @recipe, notice: "Recipe was successfully updated." }
        format.json { render :show, status: :ok, location: @recipe }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @recipe.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /recipes/1 or /recipes/1.json
  def destroy
    @recipe.destroy!

    respond_to do |format|
      format.html { redirect_to recipes_path, status: :see_other, notice: "Recipe was successfully destroyed." }
      format.json { head :no_content }
    end
  end

  def search
    @query = params[:query].to_s.strip
    @ingredient = params[:ingredient].to_s.strip
    @selected_category_ids = params[:category_ids].is_a?(Array) ? params[:category_ids].map(&:to_s) : []
    @sort = Recipe::SORT_OPTIONS.include?(params[:sort].to_s) ? params[:sort].to_s : nil
    @categories = Category.order(:name)
    @searched = @query.present? || @ingredient.present? || @selected_category_ids.any?

    if @searched
      @pagy, @recipes = paginate_recipes(
        Recipe.search(
          @query,
          category_ids: @selected_category_ids,
          ingredient: @ingredient,
          sort: @sort
        )
      )
    else
      # No search terms: nothing to paginate.
      @pagy = nil
      @recipes = Recipe.none
    end
  end

  private
    # Shared pagination for the recipe list and search results: preloads the
    # category to avoid an N+1 on the cards and applies a deterministic order
    # so page boundaries are stable.
    def paginate_recipes(scope)
      pagy(
        scope.includes(:category).order(created_at: :desc, id: :desc),
        limit: Rails.application.config.x.recipes_per_page
      )
    end

    # Use callbacks to share common setup or constraints between actions.
    def set_recipe
      @recipe = Recipe.find(params.expect(:id))
    end

    # Only allow a list of trusted parameters through.
    def recipe_params
  permitted_params = params.require(:recipe).permit(
    :title,
    :description,
    :serves,
    :instructions,
    :prep_time,
    :category_id,
    :image,
    ingredients: [ :name, :quantity, :unit ] # Nested attribute for ingredients
  )

  # Manually handle nutrition fields
  permitted_params[:nutrition] = {
    calories: params[:recipe][:nutrition_calories],
    protein: params[:recipe][:nutrition_protein],
    fat: params[:recipe][:nutrition_fat],
    carbs: params[:recipe][:nutrition_carbs],
    fibre: params[:recipe][:nutrition_fibre],
    sugar: params[:recipe][:nutrition_sugar],
    sodium: params[:recipe][:nutrition_sodium]
  }

  permitted_params
end
end

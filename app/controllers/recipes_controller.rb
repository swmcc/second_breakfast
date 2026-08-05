class RecipesController < ApplicationController
  before_action :authenticate_user!, only: [ :new, :create, :edit, :update, :destroy ]
  before_action :set_recipe, only: %i[ show edit update destroy ]

  # GET /recipes or /recipes.json
  def index
    @recipes = Recipe.all
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
    if params[:query].present?
      query = "%#{ActiveRecord::Base.sanitize_sql_like(params[:query])}%"

      if ActiveRecord::Base.connection.adapter_name.downcase.include?("postgresql")
        @recipes = Recipe.where("LOWER(title) LIKE LOWER(?) OR LOWER(ingredients::text) LIKE LOWER(?)", query, query)
      else
        @recipes = Recipe.where("LOWER(title) LIKE LOWER(?) OR LOWER(json_extract(ingredients, '$')) LIKE LOWER(?)", query, query)
      end
    else
      @recipes = []
    end
  end

  private
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

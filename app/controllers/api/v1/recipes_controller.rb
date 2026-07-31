# frozen_string_literal: true

module Api
  module V1
    class RecipesController < BaseController
      before_action :authenticate_api_token!, only: [ :create, :update, :destroy ]
      before_action :set_recipe, only: [ :show, :update, :destroy ]

      def index
        recipes = Recipe.includes(:category).order(created_at: :desc)
        @pagy, @recipes = pagy(recipes)
        @pagination = pagy_metadata(@pagy)
      end

      def show
        # @recipe set by before_action
      end

      def search
        query = params[:query].to_s.strip
        recipes = Recipe.includes(:category)
                        .where("title ILIKE :q OR description ILIKE :q", q: "%#{query}%")
                        .order(created_at: :desc)
        @pagy, @recipes = pagy(recipes)
        @pagination = pagy_metadata(@pagy)
        render :index
      end

      def create
        @recipe = Recipe.new(recipe_params)
        @recipe.save!
        render :show, status: :created
      end

      def update
        @recipe.update!(recipe_params)
        render :show
      end

      def destroy
        @recipe.destroy
        head :no_content
      end

      private

      def set_recipe
        @recipe = Recipe.find(params[:id])
      end

      def recipe_params
        params.require(:recipe).permit(
          :title, :description, :serves, :prep_time, :category_id,
          ingredients: [ :name, :quantity, :unit ],
          nutrition: {}
        ).tap do |p|
          if params[:recipe].key?(:instructions)
            p[:instructions] = params.dig(:recipe, :instructions)
          end
        end
      end
    end
  end
end

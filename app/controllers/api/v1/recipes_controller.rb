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
        attach_image if params[:recipe][:image_data].present?
        @recipe.save!

        # Fetch image in background if none provided and not explicitly disabled
        if !@recipe.image.attached? && params[:recipe][:fetch_image] != false
          FetchRecipeImageJob.perform_later(@recipe.id, @recipe.title)
        end

        render :show, status: :created
      end

      def update
        @recipe.update!(recipe_params)
        attach_image if params[:recipe][:image_data].present?
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

      def attach_image
        image_data = params[:recipe][:image_data]
        return unless image_data.present?

        # Parse data URL: data:image/jpeg;base64,/9j/4AAQ...
        if image_data.start_with?("data:")
          matches = image_data.match(%r{data:image/(\w+);base64,(.+)})
          return unless matches

          extension = matches[1]
          base64_data = matches[2]
        else
          # Assume raw base64, default to jpeg
          extension = "jpeg"
          base64_data = image_data
        end

        decoded = Base64.decode64(base64_data)
        filename = "recipe_#{Time.current.to_i}.#{extension}"

        @recipe.image.attach(
          io: StringIO.new(decoded),
          filename: filename,
          content_type: "image/#{extension}"
        )
      end
    end
  end
end

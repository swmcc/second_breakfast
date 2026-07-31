# frozen_string_literal: true

module Api
  module V1
    class CategoriesController < BaseController
      def index
        @categories = Category.all.order(:name)
      end

      def show
        @category = Category.find(params[:id])
        @pagy, @recipes = pagy(@category.recipes.includes(:category).order(created_at: :desc))
        @pagination = pagy_metadata(@pagy)
      end
    end
  end
end

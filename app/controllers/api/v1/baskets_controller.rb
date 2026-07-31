# frozen_string_literal: true

module Api
  module V1
    class BasketsController < BaseController
      before_action :authenticate_api_token!

      def index
        @baskets = current_user.baskets.includes(recipe: :category)
      end

      def create
        @basket = current_user.baskets.new(basket_params)
        @basket.save!
        render json: { message: "Recipe added to basket", basket_id: @basket.id }, status: :created
      end

      def destroy
        basket = current_user.baskets.find(params[:id])
        basket.destroy
        head :no_content
      end

      private

      def basket_params
        params.require(:basket).permit(:recipe_id)
      end
    end
  end
end

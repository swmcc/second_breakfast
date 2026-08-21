# frozen_string_literal: true

module Api
  module V1
    class BaseController < ActionController::API
      include Pagy::Backend

      before_action :authenticate_api_token!

      rescue_from ActiveRecord::RecordNotFound, with: :not_found
      rescue_from ActiveRecord::RecordInvalid, with: :unprocessable_entity
      rescue_from Pagy::OverflowError, with: :page_not_found

      private

      def authenticate_api_token!
        token = request.headers["Authorization"]&.split(" ")&.last
        api_key = ApiKey.authenticate(token)

        if api_key
          @current_api_key = api_key
          @current_user = api_key.user
          api_key.touch_last_used!
        else
          response.set_header("WWW-Authenticate", "Bearer")
          render json: { error: "Unauthorized" }, status: :unauthorized
        end
      end

      def current_user
        @current_user
      end

      def pagy_metadata(pagy)
        {
          current_page: pagy.page,
          total_pages: pagy.pages,
          total_count: pagy.count,
          per_page: pagy.limit
        }
      end

      def not_found
        render json: { error: "Not found" }, status: :not_found
      end

      def unprocessable_entity(exception)
        render json: { errors: exception.record.errors.full_messages }, status: :unprocessable_entity
      end

      def page_not_found
        render json: { error: "Page not found" }, status: :not_found
      end
    end
  end
end

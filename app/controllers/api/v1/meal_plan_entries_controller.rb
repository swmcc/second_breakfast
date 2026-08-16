# frozen_string_literal: true

module Api
  module V1
    class MealPlanEntriesController < BaseController
      before_action :set_meal_plan

      def create
        day_index = MealPlanEntry.day_index(params.dig(:entry, :day))
        if day_index.nil?
          return render json: { errors: [ "day is invalid" ] }, status: :unprocessable_entity
        end

        entry = @meal_plan.meal_plan_entries.new(
          recipe_id: params.dig(:entry, :recipe_id),
          day_of_week: day_index
        )
        entry.save!

        render json: {
          entry_id: entry.id,
          day: entry.day_name,
          recipe: {
            id: entry.recipe.id,
            title: entry.recipe.title,
            description: entry.recipe.description,
            prep_time: entry.recipe.prep_time,
            serves: entry.recipe.serves
          }
        }, status: :created
      end

      def destroy
        entry = @meal_plan.meal_plan_entries.find(params[:id])

        if entry.destroy
          head :no_content
        else
          render json: { errors: entry.errors.full_messages }, status: :unprocessable_entity
        end
      end

      private

      def set_meal_plan
        @meal_plan = current_user.meal_plans.find(params[:meal_plan_id])
      end
    end
  end
end

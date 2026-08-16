# frozen_string_literal: true

module Api
  module V1
    class MealPlansController < BaseController
      before_action :set_meal_plan, only: [ :show, :destroy, :accept, :reopen, :shopping_list ]

      def index
        plans = current_user.meal_plans.ordered
        plans = plans.active if params[:filter] == "active"
        plans = plans.archived if params[:filter] == "archived"

        @pagy, plans = pagy(plans)
        render json: {
          meal_plans: plans.map { |plan| plan_summary(plan) },
          meta: pagy_metadata(@pagy)
        }
      end

      def show
        render json: plan_json(@meal_plan)
      end

      def create
        week_start = params.dig(:meal_plan, :week_start_date).presence || Date.current
        meal_plan = current_user.meal_plans.new(week_start_date: week_start)

        if meal_plan.save
          render json: plan_json(meal_plan), status: :created
        elsif (existing = duplicate_week_plan(meal_plan))
          render json: {
            error: "A meal plan already exists for this week",
            meal_plan: plan_json(existing)
          }, status: :conflict
        else
          render json: { errors: meal_plan.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def destroy
        if @meal_plan.editable?
          @meal_plan.destroy
          head :no_content
        else
          render json: { errors: [ "Meal plan is locked" ] }, status: :unprocessable_entity
        end
      end

      def accept
        if @meal_plan.accept!
          render json: plan_json(@meal_plan)
        else
          render json: { errors: [ "Meal plan cannot be accepted" ] }, status: :unprocessable_entity
        end
      end

      def reopen
        if @meal_plan.reopen!
          render json: plan_json(@meal_plan)
        else
          render json: { errors: [ "Meal plan cannot be reopened" ] }, status: :unprocessable_entity
        end
      end

      def shopping_list
        render json: {
          week_start_date: @meal_plan.week_start_date,
          ingredients: @meal_plan.aggregated_ingredients
        }
      end

      private

      def set_meal_plan
        @meal_plan = current_user.meal_plans.find(params[:id])
      end

      def duplicate_week_plan(meal_plan)
        return nil unless meal_plan.errors.added?(:week_start_date, "already has a plan for this week")

        current_user.meal_plans.find_by(week_start_date: meal_plan.week_start_date)
      end

      def plan_summary(plan)
        {
          id: plan.id,
          week_start_date: plan.week_start_date,
          week_end_date: plan.week_end_date,
          status: plan.status,
          archived: plan.archived?,
          editable: plan.editable?,
          entry_count: plan.meal_plan_entries.size
        }
      end

      def plan_json(plan)
        entries = plan.meal_plan_entries.includes(:recipe)
        days = MealPlanEntry::DAYS.index_with { [] }
        entries.each do |entry|
          days[entry.day_name] << entry_json(entry)
        end

        plan_summary(plan).except(:entry_count).merge(days: days)
      end

      def entry_json(entry)
        {
          entry_id: entry.id,
          recipe: {
            id: entry.recipe.id,
            title: entry.recipe.title,
            description: entry.recipe.description,
            prep_time: entry.recipe.prep_time,
            serves: entry.recipe.serves
          }
        }
      end
    end
  end
end

# frozen_string_literal: true

class MealPlanEntriesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_meal_plan

  def create
    day_index = MealPlanEntry.day_index(params.dig(:entry, :day))
    entry = @meal_plan.meal_plan_entries.new(recipe_id: params.dig(:entry, :recipe_id), day_of_week: day_index)

    if day_index && entry.save
      respond_with_day_update(entry.day_name)
    else
      redirect_to @meal_plan, alert: entry.errors.full_messages.to_sentence.presence || "Could not add that meal"
    end
  end

  def destroy
    entry = @meal_plan.meal_plan_entries.find(params[:id])

    if entry.destroy
      respond_with_day_update(entry.day_name)
    else
      redirect_to @meal_plan, alert: entry.errors.full_messages.to_sentence
    end
  end

  private

  def set_meal_plan
    @meal_plan = current_user.meal_plans.find(params[:meal_plan_id])
  end

  def respond_with_day_update(day_name)
    respond_to do |format|
      format.turbo_stream do
        entries = @meal_plan.meal_plan_entries.includes(recipe: { image_attachment: :blob }).group_by(&:day_of_week)
        day_index = MealPlanEntry.day_index(day_name)

        render turbo_stream: [
          turbo_stream.replace(
            "day-#{day_name}",
            partial: "meal_plans/day_cell",
            locals: { meal_plan: @meal_plan, day_index: day_index, entries: entries[day_index] || [] }
          ),
          turbo_stream.replace(
            "shopping-list",
            partial: "meal_plans/shopping_list",
            locals: { meal_plan: @meal_plan }
          )
        ]
      end
      format.html { redirect_to @meal_plan }
    end
  end
end

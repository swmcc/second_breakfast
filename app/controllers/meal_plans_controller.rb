# frozen_string_literal: true

class MealPlansController < ApplicationController
  before_action :authenticate_user!
  before_action :set_meal_plan, only: [ :show, :destroy, :accept, :reopen, :auto_fill ]

  def index
    @current_plan = current_user.meal_plans.find_by(week_start_date: MealPlan.normalize_week_start(Date.current))
    @upcoming_plans = current_user.meal_plans.active.ordered.where.not(week_start_date: MealPlan.normalize_week_start(Date.current))
    @archived_count = current_user.meal_plans.archived.count
  end

  def show
    @entries_by_day = @meal_plan.meal_plan_entries.includes(recipe: { image_attachment: :blob }).group_by(&:day_of_week)
    return unless @meal_plan.editable?

    @saved_recipes = current_user.baskets.includes(recipe: { image_attachment: :blob }).map(&:recipe)
    @all_recipes = Recipe.includes(image_attachment: :blob).order(:title) - @saved_recipes
  end

  def create
    week_start = parse_week(params.dig(:meal_plan, :week_start_date))
    meal_plan = current_user.meal_plans.new(week_start_date: week_start)

    if meal_plan.save
      if params.dig(:meal_plan, :auto_fill) != "0"
        meal_plan.auto_fill!
        redirect_to meal_plan, notice: "Meal plan created with a week of meals picked for you — swap anything you fancy"
      else
        redirect_to meal_plan, notice: "Meal plan created — start adding meals!"
      end
    elsif (existing = current_user.meal_plans.find_by(week_start_date: MealPlan.normalize_week_start(week_start)))
      redirect_to existing, notice: "You already have a plan for that week"
    else
      redirect_to meal_plans_path, alert: meal_plan.errors.full_messages.to_sentence
    end
  end

  def destroy
    if @meal_plan.editable?
      @meal_plan.destroy
      redirect_to meal_plans_path, notice: "Meal plan deleted"
    else
      redirect_to @meal_plan, alert: "This plan is locked and cannot be deleted"
    end
  end

  def accept
    if @meal_plan.accept!
      redirect_to @meal_plan, notice: "Plan accepted — it is now locked"
    else
      redirect_to @meal_plan, alert: "This plan cannot be accepted"
    end
  end

  def reopen
    if @meal_plan.reopen!
      redirect_to @meal_plan, notice: "Plan reopened for editing"
    else
      redirect_to @meal_plan, alert: "This plan cannot be reopened"
    end
  end

  def auto_fill
    if @meal_plan.auto_fill!
      redirect_to @meal_plan, notice: "Week filled with a breakfast, lunch and dinner per day"
    else
      redirect_to @meal_plan, alert: "This plan cannot be auto-filled"
    end
  end

  def archive
    @meal_plans = current_user.meal_plans.archived.ordered
  end

  private

  def set_meal_plan
    @meal_plan = current_user.meal_plans.find(params[:id])
  end

  def parse_week(raw)
    raw.present? ? Date.parse(raw.to_s) : Date.current
  rescue ArgumentError
    Date.current
  end
end

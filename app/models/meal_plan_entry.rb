# frozen_string_literal: true

class MealPlanEntry < ApplicationRecord
  DAYS = %w[monday tuesday wednesday thursday friday saturday sunday].freeze

  belongs_to :meal_plan
  belongs_to :recipe

  validates :day_of_week, inclusion: { in: 0..6 }
  validates :recipe_id, uniqueness: { scope: [ :meal_plan_id, :day_of_week ], message: "is already planned for that day" }
  validate :meal_plan_editable, on: :create

  before_destroy :ensure_meal_plan_editable

  def self.day_index(name)
    DAYS.index(name.to_s.downcase)
  end

  def day_name
    DAYS[day_of_week]
  end

  private

  def meal_plan_editable
    errors.add(:base, "meal plan is not editable") if meal_plan && !meal_plan.editable?
  end

  def ensure_meal_plan_editable
    return if meal_plan.editable?

    errors.add(:base, "meal plan is not editable")
    throw :abort
  end
end

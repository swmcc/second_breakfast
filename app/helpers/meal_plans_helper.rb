# frozen_string_literal: true

module MealPlansHelper
  # Orders a day's entries breakfast -> lunch -> dinner -> everything else.
  def sorted_day_entries(entries)
    entries.sort_by { |entry| [ meal_slot_rank(entry.recipe), entry.recipe.title ] }
  end

  def meal_slot_rank(recipe)
    MealPlan::MEAL_SLOTS.values.index { |names| names.include?(recipe.category&.name) } || MealPlan::MEAL_SLOTS.size
  end
end

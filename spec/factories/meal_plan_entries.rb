FactoryBot.define do
  factory :meal_plan_entry do
    meal_plan
    recipe
    day_of_week { 0 }
  end
end

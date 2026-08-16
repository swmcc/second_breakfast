FactoryBot.define do
  factory :meal_plan do
    user
    week_start_date { Date.current.beginning_of_week(:monday) }
    status { "draft" }

    trait :accepted do
      status { "accepted" }
    end

    trait :archived do
      week_start_date { 2.weeks.ago.to_date.beginning_of_week(:monday) }
      to_create { |instance| instance.save!(validate: false) }
    end
  end
end

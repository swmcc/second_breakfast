FactoryBot.define do
  factory :category do
    sequence(:name) { |n| "Category #{n}" }

    trait :breakfast do
      name { "Breakfast" }
    end

    trait :lunch do
      name { "Lunch" }
    end

    trait :dinner do
      name { "Dinner" }
    end
  end
end

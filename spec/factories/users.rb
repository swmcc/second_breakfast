FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "user#{n}@example.com" }
    password { "password123" }
    password_confirmation { "password123" }

    trait :with_api_token do
      api_token { SecureRandom.hex(32) }
    end

    trait :with_basket do
      transient do
        recipes_count { 1 }
      end

      after(:create) do |user, evaluator|
        create_list(:basket, evaluator.recipes_count, user: user)
      end
    end
  end
end

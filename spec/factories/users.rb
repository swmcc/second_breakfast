FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "user#{n}@example.com" }
    password { "password123" }
    password_confirmation { "password123" }
    confirmed_at { Time.current }

    trait :unconfirmed do
      confirmed_at { nil }
    end

    trait :locked do
      failed_attempts { 0 }
      locked_until { User::LOCKOUT_PERIOD.from_now }
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

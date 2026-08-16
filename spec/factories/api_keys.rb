FactoryBot.define do
  factory :api_key do
    association :user
    sequence(:name) { |n| "Key #{n}" }

    trait :revoked do
      revoked_at { 1.hour.ago }
    end
  end
end

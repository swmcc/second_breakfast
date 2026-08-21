FactoryBot.define do
  factory :review do
    user
    recipe
    body { Faker::Food.description }
  end
end

FactoryBot.define do
  factory :rating do
    user
    recipe
    value { rand(Rating::MIN_VALUE..Rating::MAX_VALUE) }
  end
end

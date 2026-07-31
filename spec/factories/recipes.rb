FactoryBot.define do
  factory :recipe do
    sequence(:title) { |n| "Recipe #{n}" }
    description { Faker::Food.description }
    serves { rand(1..8) }
    prep_time { "#{rand(10..60)} minutes" }
    category

    ingredients do
      [
        { "name" => Faker::Food.ingredient, "quantity" => rand(1..5).to_s, "unit" => "cups" },
        { "name" => Faker::Food.ingredient, "quantity" => rand(1..3).to_s, "unit" => "tbsp" }
      ]
    end

    nutrition do
      {
        "calories" => rand(100..800).to_s,
        "protein" => "#{rand(5..40)}g",
        "fat" => "#{rand(5..30)}g",
        "carbs" => "#{rand(10..60)}g",
        "fibre" => "#{rand(2..15)}g",
        "sugar" => "#{rand(1..20)}g",
        "sodium" => "#{rand(100..1000)}mg"
      }
    end

    after(:build) do |recipe|
      recipe.instructions = Faker::Food.description if recipe.instructions.blank?
    end

    trait :with_image do
      after(:build) do |recipe|
        recipe.image.attach(
          io: File.open(Rails.root.join("spec", "fixtures", "files", "test_image.jpg")),
          filename: "test_image.jpg",
          content_type: "image/jpeg"
        )
      end
    end

    trait :high_protein do
      nutrition do
        {
          "calories" => "400",
          "protein" => "45g",
          "fat" => "15g",
          "carbs" => "20g",
          "fibre" => "5g",
          "sugar" => "3g",
          "sodium" => "500mg"
        }
      end
    end
  end
end

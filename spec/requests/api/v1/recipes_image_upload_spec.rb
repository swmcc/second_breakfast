# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::Recipes Image Upload", type: :request do
  let(:user) { create(:user, :with_api_token) }
  let(:headers) { { "Authorization" => "Bearer #{user.api_token}", "Content-Type" => "application/json", "Accept" => "application/json" } }
  let(:category) { create(:category) }

  # Small 1x1 red pixel JPEG in base64
  let(:base64_image) do
    "/9j/4AAQSkZJRgABAQEASABIAAD/2wBDAAgGBgcGBQgHBwcJCQgKDBQNDAsLDBkSEw8UHRof" \
    "Hh0aHBwgJC4nICIsIxwcKDcpLDAxNDQ0Hyc5PTgyPC4zNDL/2wBDAQkJCQwLDBgNDRgyIRwh" \
    "MjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjL/wAAR" \
    "CAABAAEDASIAAhEBAxEB/8QAFQABAQAAAAAAAAAAAAAAAAAAAAn/xAAUEAEAAAAAAAAAAAAAAAAA" \
    "AAAA/8QAFQEBAQAAAAAAAAAAAAAAAAAAAAX/xAAUEQEAAAAAAAAAAAAAAAAAAAAA/9oADAMB" \
    "AAIRAxEAPwCwAB//2Q=="
  end

  describe "POST /api/v1/recipes with image_data" do
    let(:recipe_params) do
      {
        recipe: {
          title: "Recipe with Image",
          description: "A recipe with an uploaded image",
          serves: 4,
          prep_time: "30 minutes",
          category_id: category.id,
          instructions: "Cook it well",
          ingredients: [ { name: "flour", quantity: "2", unit: "cups" } ],
          nutrition: {
            calories: "300", protein: "10g", fat: "5g",
            carbs: "40g", fibre: "3g", sugar: "5g", sodium: "200mg"
          },
          image_data: "data:image/jpeg;base64,#{base64_image}"
        }
      }
    end

    it "creates a recipe with an attached image" do
      post "/api/v1/recipes", params: recipe_params.to_json, headers: headers

      expect(response).to have_http_status(:created)
      recipe = Recipe.last
      expect(recipe.title).to eq("Recipe with Image")
      expect(recipe.image).to be_attached
    end

    it "handles raw base64 without data URL prefix" do
      recipe_params[:recipe][:image_data] = base64_image

      post "/api/v1/recipes", params: recipe_params.to_json, headers: headers

      expect(response).to have_http_status(:created)
      recipe = Recipe.last
      expect(recipe.image).to be_attached
    end
  end

  describe "PUT /api/v1/recipes/:id with image_data" do
    let!(:recipe) { create(:recipe) }

    it "attaches an image to an existing recipe" do
      params = {
        recipe: {
          image_data: "data:image/jpeg;base64,#{base64_image}"
        }
      }

      put "/api/v1/recipes/#{recipe.id}", params: params.to_json, headers: headers

      expect(response).to have_http_status(:ok)
      recipe.reload
      expect(recipe.image).to be_attached
    end
  end
end

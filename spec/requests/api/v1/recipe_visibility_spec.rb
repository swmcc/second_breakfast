# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1 recipe visibility", type: :request do
  let(:owner) { create(:user) }
  let(:other_user) { create(:user) }
  let(:owner_key) { create(:api_key, user: owner) }
  let(:other_key) { create(:api_key, user: other_user) }

  let!(:public_recipe) { create(:recipe, :public_recipe, title: "Public Pancakes") }
  let!(:private_recipe) { create(:recipe, :private_recipe, user: owner, title: "Secret Stew") }

  def auth(api_key)
    { "Authorization" => "Bearer #{api_key.token}", "Accept" => "application/json" }
  end

  describe "GET /api/v1/recipes" do
    it "hides another user's private recipes" do
      get "/api/v1/recipes", headers: auth(other_key)

      titles = response.parsed_body["recipes"].map { |r| r["title"] }
      expect(titles).to include("Public Pancakes")
      expect(titles).not_to include("Secret Stew")
    end

    it "includes the owner's own private recipes" do
      get "/api/v1/recipes", headers: auth(owner_key)

      titles = response.parsed_body["recipes"].map { |r| r["title"] }
      expect(titles).to include("Secret Stew")
    end
  end

  describe "GET /api/v1/recipes/search" do
    it "does not leak another user's private recipe" do
      get "/api/v1/recipes/search", params: { query: "Secret" }, headers: auth(other_key)

      expect(response.parsed_body["recipes"]).to be_empty
    end
  end

  describe "GET /api/v1/recipes/:id" do
    it "returns a public recipe" do
      get "/api/v1/recipes/#{public_recipe.id}", headers: auth(other_key)

      expect(response).to have_http_status(:ok)
    end

    it "404s on another user's private recipe" do
      get "/api/v1/recipes/#{private_recipe.id}", headers: auth(other_key)

      expect(response).to have_http_status(:not_found)
    end

    it "returns the owner's own private recipe" do
      get "/api/v1/recipes/#{private_recipe.id}", headers: auth(owner_key)

      expect(response).to have_http_status(:ok)
    end

    it "exposes the visibility and share URL" do
      get "/api/v1/recipes/#{public_recipe.id}", headers: auth(other_key)

      expect(response.parsed_body["visibility"]).to eq("public")
      expect(response.parsed_body["share_url"]).to include(public_recipe.public_token)
    end
  end

  describe "PATCH /api/v1/recipes/:id" do
    it "404s on another user's private recipe" do
      patch "/api/v1/recipes/#{private_recipe.id}",
            params: { recipe: { title: "Hijacked" } }.to_json,
            headers: auth(other_key).merge("Content-Type" => "application/json")

      expect(response).to have_http_status(:not_found)
      expect(private_recipe.reload.title).to eq("Secret Stew")
    end
  end

  describe "DELETE /api/v1/recipes/:id" do
    it "404s on another user's private recipe" do
      delete "/api/v1/recipes/#{private_recipe.id}", headers: auth(other_key)

      expect(response).to have_http_status(:not_found)
      expect(Recipe.exists?(private_recipe.id)).to be true
    end
  end

  describe "POST /api/v1/recipes" do
    let(:category) { create(:category) }

    it "records the API key's user as the owner" do
      post "/api/v1/recipes",
           params: {
             recipe: {
               title: "API Recipe",
               description: "Made over the API",
               serves: 2,
               prep_time: "5 minutes",
               category_id: category.id,
               instructions: "Cook it",
               visibility: "private",
               ingredients: [ { name: "Eggs", quantity: "2", unit: "pieces" } ],
               nutrition: {
                 calories: "200", protein: "14g", fat: "15g", carbs: "2g",
                 fibre: "0g", sugar: "1g", sodium: "300mg"
               }
             },
             fetch_image: false
           }.to_json,
           headers: auth(owner_key).merge("Content-Type" => "application/json")

      expect(response).to have_http_status(:created)
      recipe = Recipe.find_by(title: "API Recipe")
      expect(recipe.user).to eq(owner)
      expect(recipe).to be_private_recipe
    end
  end
end

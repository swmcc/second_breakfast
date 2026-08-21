# frozen_string_literal: true

require "rails_helper"

# Guards the pagy 9.x pagination contract for the JSON API.
#
# The app is deliberately pinned to pagy 9.x (see UPGRADE_NOTES.md). pagy v43
# renames Pagy::Backend to Pagy::Method and changes pagy(collection) to
# pagy(:offset, collection), so an accidental major bump must fail here loudly
# rather than silently reshaping the payload.
RSpec.describe "Api::V1 pagination", type: :request do
  let(:api_key) { create(:api_key) }
  let(:user) { api_key.user }
  let(:headers) { { "Authorization" => "Bearer #{api_key.token}", "Accept" => "application/json" } }

  def pagination_from(body)
    body["pagination"] || body["meta"]
  end

  describe "configuration" do
    it "defaults to 20 records per page" do
      expect(Pagy::DEFAULT[:limit]).to eq(20)
    end

    it "clamps overflowing pages to the last page" do
      expect(Pagy::DEFAULT[:overflow]).to eq(:last_page)
    end
  end

  describe "GET /api/v1/recipes" do
    before { create_list(:recipe, 25) }

    it "returns the first page with the full pagination payload" do
      get "/api/v1/recipes", headers: headers

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["recipes"].size).to eq(20)
      expect(pagination_from(response.parsed_body)).to eq(
        "current_page" => 1,
        "total_pages" => 2,
        "total_count" => 25,
        "per_page" => 20
      )
    end

    it "honours the page parameter" do
      get "/api/v1/recipes", params: { page: 2 }, headers: headers

      expect(response.parsed_body["recipes"].size).to eq(5)
      expect(pagination_from(response.parsed_body)).to include(
        "current_page" => 2,
        "total_pages" => 2,
        "total_count" => 25,
        "per_page" => 20
      )
    end

    it "returns the last page rather than raising when the page overflows" do
      get "/api/v1/recipes", params: { page: 99 }, headers: headers

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["recipes"].size).to eq(5)
      expect(pagination_from(response.parsed_body)).to include("current_page" => 2, "total_pages" => 2)
    end

    it "reports a single empty page when there is nothing to paginate" do
      Recipe.delete_all

      get "/api/v1/recipes", headers: headers

      expect(response.parsed_body["recipes"]).to be_empty
      expect(pagination_from(response.parsed_body)).to include(
        "current_page" => 1,
        "total_pages" => 1,
        "total_count" => 0,
        "per_page" => 20
      )
    end
  end

  describe "GET /api/v1/recipes/search" do
    it "paginates search results with the same payload shape" do
      create_list(:recipe, 21, title: "Paginated pancakes")
      create(:recipe, title: "Unrelated stew")

      get "/api/v1/recipes/search", params: { query: "Paginated" }, headers: headers

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["recipes"].size).to eq(20)
      expect(pagination_from(response.parsed_body)).to include(
        "current_page" => 1,
        "total_pages" => 2,
        "total_count" => 21,
        "per_page" => 20
      )
    end
  end

  describe "GET /api/v1/categories/:id" do
    it "paginates the category's recipes" do
      category = create(:category)
      create_list(:recipe, 22, category: category)

      get "/api/v1/categories/#{category.id}", headers: headers

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["recipes"].size).to eq(20)
      expect(pagination_from(response.parsed_body)).to eq(
        "current_page" => 1,
        "total_pages" => 2,
        "total_count" => 22,
        "per_page" => 20
      )
    end
  end

  describe "GET /api/v1/meal_plans" do
    it "returns the pagination payload under meta" do
      create(:meal_plan, user: user)
      create(:meal_plan, :archived, user: user)

      get "/api/v1/meal_plans", headers: headers

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["meal_plans"].size).to eq(2)
      expect(response.parsed_body["meta"]).to eq(
        "current_page" => 1,
        "total_pages" => 1,
        "total_count" => 2,
        "per_page" => 20
      )
    end
  end
end

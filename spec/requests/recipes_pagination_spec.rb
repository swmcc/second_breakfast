require "rails_helper"

RSpec.describe "Recipes pagination" do
  let(:per_page) { Rails.application.config.x.recipes_per_page }

  # Ordered newest first (created_at desc, id desc), so "Paginated Recipe 15"
  # heads page one and "Paginated Recipe 01" tails the last page.
  let!(:recipes) do
    (1..15).map { |n| create(:recipe, title: format("Paginated Recipe %02d", n)) }
  end

  let(:first_page_titles) { recipes.last(per_page).map(&:title) }
  let(:second_page_titles) { recipes.first(15 - per_page).map(&:title) }

  it "defaults to 12 recipes per page" do
    expect(per_page).to eq(12)
  end

  describe "GET /recipes" do
    it "shows only the first page of recipes" do
      get recipes_path

      expect(response).to have_http_status(:ok)
      first_page_titles.each { |title| expect(response.body).to include(title) }
      second_page_titles.each { |title| expect(response.body).not_to include(title) }
    end

    it "renders a link to the next page" do
      get recipes_path

      expect(response.body).to include("Next")
      expect(response.body).to include("/recipes?page=2")
    end

    it "shows the remaining recipes on page 2" do
      get recipes_path, params: { page: 2 }

      expect(response).to have_http_status(:ok)
      second_page_titles.each { |title| expect(response.body).to include(title) }
      first_page_titles.each { |title| expect(response.body).not_to include(title) }
    end

    it "falls back to the last page when the page is out of range" do
      get recipes_path, params: { page: 99 }

      expect(response).to have_http_status(:ok)
      second_page_titles.each { |title| expect(response.body).to include(title) }
    end

    it "does not render the nav when everything fits on one page" do
      Recipe.destroy_all
      create(:recipe, title: "Only Recipe")

      get recipes_path

      expect(response.body).to include("Only Recipe")
      expect(response.body).not_to include('aria-label="Pagination"')
    end
  end

  describe "GET /recipes/search" do
    it "paginates matching recipes" do
      get search_recipes_path, params: { query: "Paginated Recipe" }

      expect(response).to have_http_status(:ok)
      first_page_titles.each { |title| expect(response.body).to include(title) }
      second_page_titles.each { |title| expect(response.body).not_to include(title) }
    end

    it "keeps the query when paging" do
      get search_recipes_path, params: { query: "Paginated Recipe", page: 2 }

      expect(response).to have_http_status(:ok)
      second_page_titles.each { |title| expect(response.body).to include(title) }
      expect(response.body).to include("query=Paginated+Recipe")
    end

    it "falls back to the last page when the page is out of range" do
      get search_recipes_path, params: { query: "Paginated Recipe", page: 99 }

      expect(response).to have_http_status(:ok)
      second_page_titles.each { |title| expect(response.body).to include(title) }
    end

    it "renders the empty state for a blank query without a pagination nav" do
      get search_recipes_path, params: { query: "" }

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include('aria-label="Pagination"')
    end
  end

  describe "saving a recipe from a paginated list" do
    let(:user) { create(:user) }

    before { sign_in(user) }

    it "returns the user to the page they were on" do
      post toggle_meal_path, params: { recipe_id: recipes.first.id },
                             headers: { "HTTP_REFERER" => "#{recipes_url}?page=2" }

      expect(response).to redirect_to("#{recipes_url}?page=2")
    end
  end
end

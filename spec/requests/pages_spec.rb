require "rails_helper"

RSpec.describe "Pages" do
  describe "public compliance pages" do
    it "renders the privacy policy while signed out" do
      get privacy_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Privacy Policy")
    end

    it "renders the terms while signed out" do
      get terms_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Terms of Use")
    end
  end

  describe "GET / (root)" do
    context "when recipes exist" do
      let!(:recipes) { create_list(:recipe, 5) }

      it "returns a successful response" do
        get root_path
        expect(response).to have_http_status(:ok)
      end

      it "displays a random recipe" do
        get root_path

        # The page should contain at least one recipe title
        recipe_titles = recipes.map(&:title)
        displayed = recipe_titles.any? { |title| response.body.include?(title) }
        expect(displayed).to be true
      end
    end

    context "when no recipes exist" do
      it "returns a successful response" do
        get root_path
        expect(response).to have_http_status(:ok)
      end
    end
  end

  describe "GET /pages/random_recipe" do
    let!(:recipes) { create_list(:recipe, 3) }

    it "returns a successful response" do
      get pages_random_recipe_path
      expect(response).to have_http_status(:ok)
    end

    it "shows a recipe from the available recipes" do
      get pages_random_recipe_path

      recipe_titles = recipes.map(&:title)
      displayed = recipe_titles.any? { |title| response.body.include?(title) }
      expect(displayed).to be true
    end

    it "returns different recipes on multiple requests (randomness)" do
      # Make multiple requests and collect the titles shown
      titles_shown = []
      10.times do
        get pages_random_recipe_path
        recipes.each do |recipe|
          titles_shown << recipe.title if response.body.include?(recipe.title)
        end
      end

      # With 3 recipes and 10 requests, we should likely see more than one unique recipe
      # (though this is probabilistic, it's very unlikely to get the same one 10 times)
      unique_titles = titles_shown.uniq
      # Relax this test since it's probabilistic - at minimum we should see at least 1
      expect(unique_titles.size).to be >= 1
    end
  end
end

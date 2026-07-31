require "rails_helper"

RSpec.describe "Home Page", type: :system do
  describe "random recipe display" do
    it "shows a random recipe when recipes exist" do
      recipes = create_list(:recipe, 3)

      visit root_path

      # Should show at least one of the recipe titles
      recipe_titles = recipes.map(&:title)
      displayed = recipe_titles.any? { |title| page.has_content?(title) }
      expect(displayed).to be true
    end

    it "handles the case when no recipes exist" do
      visit root_path

      expect(page).to have_http_status(:ok)
    end
  end

  describe "navigation" do
    it "allows navigating to recipes page" do
      visit root_path

      click_link "Recipes"

      expect(page).to have_current_path(recipes_path)
    end

    it "allows navigating to categories page" do
      visit root_path

      click_link "Categories"

      expect(page).to have_current_path(categories_path)
    end
  end
end

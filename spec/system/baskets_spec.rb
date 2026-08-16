require "rails_helper"

RSpec.describe "Baskets", type: :system do
  let(:user) { create(:user) }
  let!(:recipe) { create(:recipe, title: "Pancakes for Breakfast") }

  describe "basket functionality" do
    before { sign_in_as(user) }

    it "shows the basket count in the header" do
      visit recipes_path

      # User starts with 0 meals
      expect(page).to have_content("0 Saved Recipes")
    end

    it "updates basket count when adding a recipe" do
      # Create a basket entry directly
      create(:basket, user: user, recipe: recipe)

      visit recipes_path

      expect(page).to have_content("1 Saved Recipe")
    end

    it "shows multiple meals when basket has multiple recipes" do
      recipes = create_list(:recipe, 3)
      recipes.each { |r| create(:basket, user: user, recipe: r) }

      visit recipes_path

      expect(page).to have_content("3 Saved Recipes")
    end
  end

  describe "unauthenticated users" do
    it "does not show basket count" do
      visit recipes_path

      expect(page).not_to have_content("Meals")
    end
  end
end

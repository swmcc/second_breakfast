require "rails_helper"

RSpec.describe "Recipes", type: :system do
  let(:user) { create(:user) }
  let(:category) { create(:category, name: "Breakfast") }

  describe "browsing recipes" do
    it "shows all recipes on the index page" do
      recipes = create_list(:recipe, 3)

      visit recipes_path

      recipes.each do |recipe|
        expect(page).to have_content(recipe.title)
      end
    end

    it "can view a recipe details page" do
      recipe = create(:recipe, title: "Delicious Pancakes")

      visit recipe_path(recipe)

      expect(page).to have_content("Delicious Pancakes")
    end
  end

  describe "searching recipes" do
    let!(:pancakes) { create(:recipe, title: "Fluffy Pancakes") }
    let!(:omelette) { create(:recipe, title: "Cheese Omelette") }

    it "finds recipes by title using the search form" do
      visit recipes_path

      fill_in "query", with: "pancakes"
      find("input[name='query']").send_keys(:enter)

      expect(page).to have_content("Fluffy Pancakes")
      expect(page).not_to have_content("Cheese Omelette")
    end
  end

  describe "recipe management" do
    before do
      category
      sign_in_as(user)
    end

    it "can access the new recipe page when authenticated" do
      visit new_recipe_path

      expect(page).to have_content("New recipe")
      expect(page).to have_field("Title")
    end

    context "with an existing recipe" do
      let!(:recipe) { create(:recipe, title: "Old Title") }

      it "can view the edit page" do
        visit edit_recipe_path(recipe)

        expect(page).to have_field("Title", with: "Old Title")
      end
    end
  end
end

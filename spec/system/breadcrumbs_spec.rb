require "rails_helper"

RSpec.describe "Breadcrumbs", type: :system do
  let(:user) { create(:user) }

  it "shows the trail down to a recipe and marks the current page" do
    recipe = create(:recipe, title: "Buttered Crumpets")

    visit recipe_path(recipe)

    within("nav[aria-label='Breadcrumb']") do
      expect(page).to have_link("Home", href: root_path)
      expect(page).to have_link("Recipes", href: recipes_path)
      expect(page).to have_css("[aria-current='page']", text: "Buttered Crumpets")
      expect(page).to have_no_link("Buttered Crumpets")
    end
  end

  it "uses an ordered list so the trail has an order for assistive tech" do
    visit recipes_path

    expect(page).to have_css("nav[aria-label='Breadcrumb'] ol li", minimum: 2)
  end

  it "links back up the trail" do
    recipe = create(:recipe)

    visit recipe_path(recipe)
    within("nav[aria-label='Breadcrumb']") { click_link "Recipes" }

    expect(page).to have_current_path(recipes_path)
  end

  it "includes the recipe when editing it" do
    recipe = create(:recipe, title: "Buttered Crumpets")
    sign_in_as(user)

    visit edit_recipe_path(recipe)

    within("nav[aria-label='Breadcrumb']") do
      expect(page).to have_link("Buttered Crumpets", href: recipe_path(recipe))
      expect(page).to have_css("[aria-current='page']", text: "Edit")
    end
  end

  it "is absent from pages that do not declare a trail" do
    visit about_path

    expect(page).to have_no_css("nav[aria-label='Breadcrumb']")
  end
end

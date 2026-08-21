require "rails_helper"

RSpec.describe "Recipes pagination", type: :system do
  it "pages through the recipe list" do
    recipes = (1..15).map { |n| create(:recipe, title: format("Paginated Recipe %02d", n)) }
    newest = recipes.last.title
    oldest = recipes.first.title

    visit recipes_path

    expect(page).to have_content(newest)
    expect(page).to have_no_content(oldest)

    click_link "Next →"

    expect(page).to have_content(oldest)
    expect(page).to have_no_content(newest)
    expect(page).to have_current_path(recipes_path(page: 2))
  end
end

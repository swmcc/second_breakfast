require "rails_helper"

RSpec.describe "Navigation", type: :system do
  let(:user) { create(:user, email: "test@example.com") }

  describe "user dropdown menu" do
    context "when signed in" do
      before { sign_in_as(user) }

      it "displays the meal plan and saved recipes links in the main nav" do
        visit root_path
        expect(page).to have_link(href: meal_plans_path)
        expect(page).to have_link(href: meals_path)
        expect(page).to have_content("0 Saved Recipes")
      end

      it "displays the user email as a dropdown trigger" do
        visit root_path
        expect(page).to have_button(user.email)
      end

      it "shows dropdown menu when clicking user email" do
        visit root_path
        click_button user.email

        within("[data-dropdown-target='menu']") do
          expect(page).to have_content("Signed in as")
          expect(page).to have_content(user.email)
          expect(page).to have_link("Sign out")
        end
      end

      it "allows signing out from the dropdown" do
        visit root_path
        click_button user.email
        click_link "Sign out"

        expect(page).to have_current_path(root_path)
        expect(page).to have_link("Sign In")
      end

      it "closes dropdown when clicking outside" do
        visit root_path
        click_button user.email

        expect(page).to have_css("[data-dropdown-target='menu']:not(.hidden)")

        find("body").click

        expect(page).to have_css("[data-dropdown-target='menu'].hidden", visible: false)
      end
    end

    context "when signed out" do
      it "displays sign in link" do
        visit root_path
        expect(page).to have_link("Sign In")
        expect(page).not_to have_button(text: /@/)
      end
    end
  end

  describe "basket counter" do
    before { sign_in_as(user) }

    it "updates when recipes are added to basket" do
      recipe = create(:recipe)
      create(:basket, user: user, recipe: recipe)

      visit root_path
      expect(page).to have_content("1 Saved Recipe")
    end

    it "shows plural for multiple saved recipes" do
      recipes = create_list(:recipe, 3)
      recipes.each { |r| create(:basket, user: user, recipe: r) }

      visit root_path
      expect(page).to have_content("3 Saved Recipes")
    end
  end
end

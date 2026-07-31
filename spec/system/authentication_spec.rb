require "rails_helper"

RSpec.describe "Authentication", type: :system do
  let(:user) { create(:user, email: "test@example.com") }

  describe "signing in" do
    it "allows a user to sign in with valid credentials" do
      visit sign_in_path

      fill_in "Email", with: user.email
      fill_in "Password", with: "password123"
      click_button "Sign in"

      expect(page).to have_current_path(root_path)
      expect(page).to have_content(user.email)
    end

    it "does not redirect with invalid credentials" do
      visit sign_in_path

      fill_in "Email", with: user.email
      fill_in "Password", with: "wrongpassword"
      click_button "Sign in"

      # User stays on sign in form, not redirected to home
      expect(page).not_to have_current_path(root_path)
      expect(page).to have_button("Sign in")
    end
  end

  describe "signing out" do
    before { sign_in_as(user) }

    it "allows a user to sign out" do
      click_link "Sign Out"

      expect(page).to have_current_path(root_path)
      expect(page).to have_link("Sign In")
    end
  end

  describe "protected routes" do
    it "redirects to sign in when accessing protected pages" do
      visit new_recipe_path

      expect(page).to have_current_path(sign_in_path)
    end

    it "allows access to protected pages after signing in" do
      sign_in_as(user)
      visit new_recipe_path

      expect(page).to have_current_path(new_recipe_path)
      expect(page).to have_content("New recipe")
    end
  end
end

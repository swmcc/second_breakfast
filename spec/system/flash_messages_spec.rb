require "rails_helper"

RSpec.describe "Flash messages", type: :system do
  let(:user) { create(:user) }

  describe "success notices" do
    it "announce politely and can be dismissed" do
      sign_in_as(user)

      expect(page).to have_css("[role='status']", text: "Logged in successfully")

      within("[role='status']") { click_button "Dismiss success notification" }

      expect(page).to have_no_content("Logged in successfully")
    end

    it "are rendered once, by the layout, rather than repeated per page" do
      recipe = create(:recipe)
      sign_in_as(user)

      visit recipes_path
      click_link "Plan #{recipe.title}"

      expect(page).to have_css("#flash-messages", count: 1)
      expect(page).to have_content("Recipe saved!", count: 1)
    end
  end

  describe "failures" do
    it "interrupt with role=alert and are not auto-dismissed" do
      visit sign_in_path

      fill_in "Email", with: user.email
      fill_in "Password", with: "definitely-wrong"
      click_button "Sign in"

      expect(page).to have_css("[role='alert']", text: "Invalid email or password")
      expect(page).to have_css("[data-flash-kind='alert']:not([data-flash-auto-dismiss-value])")
    end
  end
end

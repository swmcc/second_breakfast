require "rails_helper"

RSpec.describe "Accessibility", type: :system do
  describe "skip to main content link" do
    it "is the first thing a keyboard user reaches and jumps to the main landmark" do
      visit root_path

      page.driver.browser.keyboard.type(:Tab)

      expect(page).to have_link("Skip to main content", visible: :visible)
      expect(page.evaluate_script("document.activeElement.textContent.trim()"))
        .to eq("Skip to main content")

      click_link "Skip to main content"

      expect(page.evaluate_script("document.activeElement.id")).to eq("main-content")
    end
  end

  describe "landmarks" do
    it "exposes labelled banner, navigation, main and contentinfo regions" do
      visit root_path

      expect(page).to have_css("header nav[aria-label='Main']", visible: :all)
      expect(page).to have_css("main#main-content", visible: :all)
      expect(page).to have_css("footer nav[aria-label='Footer']", visible: :all)
    end

    it "declares the document language" do
      visit root_path

      expect(page).to have_css("html[lang='en']", visible: :all)
    end
  end

  describe "the search field" do
    it "has an accessible name even though its label is visually hidden" do
      visit root_path

      expect(page).to have_field("Search recipes")
    end
  end

  describe "recipe images" do
    it "are given descriptive alt text" do
      recipe = create(:recipe, title: "Buttered Crumpets")
      recipe.image.attach(
        io: File.open(Rails.root.join("app/assets/images/recipes/pancakes.png")),
        filename: "pancakes.png",
        content_type: "image/png"
      )

      visit recipes_path

      expect(page).to have_css("img[alt='Photograph of Buttered Crumpets']")
    end

    it "fall back to a decorative placeholder when no photo is attached" do
      create(:recipe, title: "Buttered Crumpets")

      visit recipes_path

      expect(page).to have_css("[aria-hidden='true'] svg")
      expect(page).to have_no_css("img[alt='']")
    end
  end

  describe "the account menu" do
    let(:user) { create(:user) }

    before { sign_in_as(user) }

    it "reports its expanded state and closes on Escape" do
      visit root_path

      expect(page).to have_button(user.email)
      expect(find_button(user.email)["aria-expanded"]).to eq("false")

      click_button user.email
      expect(find_button(user.email)["aria-expanded"]).to eq("true")

      page.driver.browser.keyboard.type(:Escape)

      expect(page).to have_css("[data-dropdown-target='menu'].hidden", visible: :all)
      expect(find_button(user.email)["aria-expanded"]).to eq("false")
    end

    it "moves focus into the menu with the down arrow key" do
      visit root_path

      find_button(user.email).click
      page.driver.browser.keyboard.type(:Down)

      expect(page.evaluate_script("document.activeElement.getAttribute('role')")).to eq("menuitem")
    end
  end
end

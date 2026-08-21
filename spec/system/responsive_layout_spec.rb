require "rails_helper"

RSpec.describe "Responsive layout", type: :system do
  let(:user) { create(:user) }

  # 375px is an iPhone SE/13 mini, 768px an iPad portrait, 1280px a laptop.
  WIDTHS = { "mobile" => 375, "tablet" => 768, "desktop" => 1280 }.freeze

  def horizontal_overflow?
    page.evaluate_script(
      "document.documentElement.scrollWidth > document.documentElement.clientWidth + 1"
    )
  end

  after { page.driver.resize_window(1200, 800) }

  WIDTHS.each do |name, width|
    context "at #{width}px (#{name})" do
      before { page.driver.resize_window(width, 900) }

      it "does not scroll the recipe index sideways" do
        create_list(:recipe, 3)

        visit recipes_path

        expect(horizontal_overflow?).to be false
      end

      it "does not scroll a recipe page sideways" do
        recipe = create(:recipe)

        visit recipe_path(recipe)

        expect(horizontal_overflow?).to be false
      end

      it "does not scroll the saved recipes page sideways" do
        sign_in_as(user)
        create(:basket, user: user, recipe: create(:recipe))

        visit meals_path

        expect(horizontal_overflow?).to be false
      end
    end
  end

  describe "the small-screen navigation" do
    before { page.driver.resize_window(375, 900) }

    it "stays closed until the menu button is pressed" do
      visit root_path

      expect(page).to have_no_link("Categories", visible: :visible)

      click_button "Open main menu"

      expect(page).to have_link("Categories", visible: :visible)
      expect(find_button("Open main menu", visible: :all)["aria-expanded"]).to eq("true")
    end

    it "closes again from the close button" do
      visit root_path

      click_button "Open main menu"
      click_button "Close menu"

      expect(page).to have_no_link("Categories", visible: :visible)
    end

    it "closes on Escape" do
      visit root_path

      click_button "Open main menu"
      page.driver.browser.keyboard.type(:Escape)

      expect(page).to have_no_link("Categories", visible: :visible)
    end
  end

  describe "tap targets" do
    it "gives the mobile menu button at least 44px in both directions" do
      page.driver.resize_window(375, 900)
      visit root_path

      box = page.evaluate_script(<<~JS)
        (() => {
          const rect = document.querySelector("[data-mobile-menu-target='trigger']").getBoundingClientRect()
          return [rect.width, rect.height]
        })()
      JS

      expect(box[0]).to be >= 44
      expect(box[1]).to be >= 44
    end
  end

  describe "the sticky header" do
    it "stays put while the page scrolls" do
      create_list(:recipe, 12)

      visit recipes_path
      page.execute_script("window.scrollTo(0, 800)")

      top = page.evaluate_script("document.querySelector('header').getBoundingClientRect().top")

      expect(top).to be_within(1).of(0)
    end
  end
end

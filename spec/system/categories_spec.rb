require "rails_helper"

RSpec.describe "Categories", type: :system do
  let(:user) { create(:user) }

  describe "browsing categories" do
    it "shows all categories on the index page" do
      categories = create_list(:category, 3)

      visit categories_path

      categories.each do |category|
        expect(page).to have_content(category.name)
      end
    end

    it "can view a category detail page" do
      category = create(:category, name: "Breakfast Foods")

      visit category_path(category)

      expect(page).to have_content("Breakfast Foods")
    end
  end

  describe "category management" do
    before { sign_in_as(user) }

    it "can access the new category page when authenticated" do
      visit new_category_path

      expect(page).to have_field("Name")
    end

    it "can create a new category" do
      visit new_category_path

      fill_in "Name", with: "Desserts"
      click_button "Create Category"

      expect(page).to have_content("Category was successfully created")
      expect(page).to have_content("Desserts")
    end

    context "with an existing category" do
      let!(:category) { create(:category, name: "Old Category") }

      it "can view the edit page" do
        visit edit_category_path(category)

        expect(page).to have_field("Name", with: "Old Category")
      end

      it "can update the category" do
        visit edit_category_path(category)

        fill_in "Name", with: "New Name"
        click_button "Update Category"

        expect(page).to have_content("Category was successfully updated")
        expect(page).to have_content("New Name")
      end
    end
  end
end

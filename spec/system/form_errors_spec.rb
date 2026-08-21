require "rails_helper"

RSpec.describe "Form validation feedback", type: :system do
  let(:user) { create(:user) }

  before { sign_in_as(user) }

  describe "the category form" do
    it "shows a summary at the top and an inline message beside the field" do
      visit new_category_path

      fill_in "Name", with: ""
      click_button "Create Category"

      within("#error_explanation") do
        expect(page).to have_content("1 error prohibited this category from being saved")
        expect(page).to have_link("Name can't be blank", href: "#category_name")
      end

      expect(page).to have_css("#category_name_error", text: "Name can't be blank")
    end

    it "wires the invalid field to its message with aria-invalid and aria-describedby" do
      visit new_category_path

      fill_in "Name", with: ""
      click_button "Create Category"

      field = find_field("Name")
      expect(field["aria-invalid"]).to eq("true")
      expect(field["aria-describedby"]).to eq("category_name_error")
    end

    it "announces the summary as an alert and gives it focus" do
      visit new_category_path

      fill_in "Name", with: ""
      click_button "Create Category"

      expect(page).to have_css("#error_explanation[role='alert']")
      expect(page.evaluate_script("document.activeElement.id")).to eq("error_explanation")
    end

    it "clears the feedback once the form is valid" do
      visit new_category_path

      click_button "Create Category"
      expect(page).to have_css("#error_explanation")

      fill_in "Name", with: "Elevenses"
      click_button "Create Category"

      expect(page).to have_no_css("#error_explanation")
      expect(Category.find_by(name: "Elevenses")).to be_present
    end
  end

  describe "the recipe form" do
    it "reports every missing field in the summary" do
      create(:category)
      visit new_recipe_path

      click_button "Create Recipe"

      within("#error_explanation") do
        expect(page).to have_content("prohibited this recipe from being saved")
        expect(page).to have_link("Title can't be blank", href: "#recipe_title")
      end

      expect(page).to have_css("#recipe_title_error", text: "Title can't be blank")
      expect(find_field("Title")["aria-invalid"]).to eq("true")
    end
  end
end

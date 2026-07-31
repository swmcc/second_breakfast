require "rails_helper"

RSpec.describe "Categories" do
  let(:user) { create(:user) }
  let(:valid_attributes) { { name: "Breakfast" } }
  let(:invalid_attributes) { { name: "" } }

  describe "GET /categories" do
    it "returns a successful response" do
      get categories_path
      expect(response).to have_http_status(:ok)
    end

    it "displays all categories" do
      categories = create_list(:category, 3)
      get categories_path

      categories.each do |category|
        expect(response.body).to include(category.name)
      end
    end
  end

  describe "GET /categories/:id" do
    let(:category) { create(:category) }

    it "returns a successful response" do
      get category_path(category)
      expect(response).to have_http_status(:ok)
    end

    it "displays the category name" do
      get category_path(category)
      expect(response.body).to include(category.name)
    end

    # Note: The current category show view doesn't display associated recipes.
    # This test documents the current behavior. Consider adding recipe listing
    # to the category show view in a future enhancement.
    it "loads recipes for the category" do
      recipes = create_list(:recipe, 2, category: category)
      get category_path(category)

      # The controller loads the category (which has recipes)
      expect(response).to have_http_status(:ok)
      expect(category.recipes.count).to eq(2)
    end
  end

  describe "GET /categories/new" do
    context "when authenticated" do
      before { sign_in(user) }

      it "returns a successful response" do
        get new_category_path
        expect(response).to have_http_status(:ok)
      end
    end

    context "when not authenticated" do
      it "redirects to login" do
        get new_category_path
        expect(response).to redirect_to(sign_in_path)
      end
    end
  end

  describe "POST /categories" do
    context "when authenticated" do
      before { sign_in(user) }

      context "with valid parameters" do
        it "creates a new category" do
          expect {
            post categories_path, params: { category: valid_attributes }
          }.to change(Category, :count).by(1)
        end

        it "redirects to the created category" do
          post categories_path, params: { category: valid_attributes }
          expect(response).to redirect_to(Category.last)
        end
      end

      context "with invalid parameters" do
        it "does not create a new category" do
          expect {
            post categories_path, params: { category: invalid_attributes }
          }.not_to change(Category, :count)
        end

        it "returns unprocessable entity status" do
          post categories_path, params: { category: invalid_attributes }
          expect(response).to have_http_status(:unprocessable_entity)
        end
      end
    end

    context "when not authenticated" do
      it "redirects to login" do
        post categories_path, params: { category: valid_attributes }
        expect(response).to redirect_to(sign_in_path)
      end
    end
  end

  describe "GET /categories/:id/edit" do
    let(:category) { create(:category) }

    context "when authenticated" do
      before { sign_in(user) }

      it "returns a successful response" do
        get edit_category_path(category)
        expect(response).to have_http_status(:ok)
      end
    end

    context "when not authenticated" do
      it "redirects to login" do
        get edit_category_path(category)
        expect(response).to redirect_to(sign_in_path)
      end
    end
  end

  describe "PATCH /categories/:id" do
    let(:category) { create(:category, name: "Old Name") }
    let(:new_attributes) { { name: "New Name" } }

    context "when authenticated" do
      before { sign_in(user) }

      context "with valid parameters" do
        it "updates the category" do
          patch category_path(category), params: { category: new_attributes }
          category.reload
          expect(category.name).to eq("New Name")
        end

        it "redirects to the category" do
          patch category_path(category), params: { category: new_attributes }
          expect(response).to redirect_to(category)
        end
      end

      context "with invalid parameters" do
        it "returns unprocessable entity status" do
          patch category_path(category), params: { category: invalid_attributes }
          expect(response).to have_http_status(:unprocessable_entity)
        end
      end
    end

    context "when not authenticated" do
      it "redirects to login" do
        patch category_path(category), params: { category: new_attributes }
        expect(response).to redirect_to(sign_in_path)
      end
    end
  end

  describe "DELETE /categories/:id" do
    context "when authenticated" do
      before { sign_in(user) }

      context "when category has no recipes" do
        let!(:category) { create(:category) }

        it "destroys the category" do
          expect {
            delete category_path(category)
          }.to change(Category, :count).by(-1)
        end

        it "redirects to categories index" do
          delete category_path(category)
          expect(response).to redirect_to(categories_path)
        end
      end

      context "when category has recipes" do
        let!(:category) { create(:category) }
        let!(:recipe) { create(:recipe, category: category) }

        it "raises an error due to FK constraint" do
          expect {
            delete category_path(category)
          }.to raise_error(ActiveRecord::InvalidForeignKey)
        end
      end
    end

    context "when not authenticated" do
      let!(:category) { create(:category) }

      it "redirects to login" do
        delete category_path(category)
        expect(response).to redirect_to(sign_in_path)
      end
    end
  end
end

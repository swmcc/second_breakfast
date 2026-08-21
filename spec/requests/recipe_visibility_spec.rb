# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Recipe visibility" do
  let(:owner) { create(:user) }
  let(:other_user) { create(:user) }
  let!(:public_recipe) { create(:recipe, :public_recipe, title: "Public Pancakes") }
  let!(:private_recipe) { create(:recipe, :private_recipe, user: owner, title: "Secret Stew") }

  describe "GET /recipes/:id" do
    context "when signed out" do
      it "shows a public recipe" do
        get recipe_path(public_recipe)

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Public Pancakes")
      end

      it "does not show a private recipe" do
        get recipe_path(private_recipe)

        expect(response).to have_http_status(:not_found)
      end
    end

    context "when signed in as the owner" do
      before { sign_in(owner) }

      it "shows their own private recipe" do
        get recipe_path(private_recipe)

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Secret Stew")
      end
    end

    context "when signed in as someone else" do
      before { sign_in(other_user) }

      it "does not show another user's private recipe" do
        get recipe_path(private_recipe)

        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "GET /recipes" do
    it "hides private recipes from signed-out visitors" do
      get recipes_path

      expect(response.body).to include("Public Pancakes")
      expect(response.body).not_to include("Secret Stew")
    end

    it "hides another user's private recipes" do
      sign_in(other_user)
      get recipes_path

      expect(response.body).not_to include("Secret Stew")
    end

    it "includes the owner's own private recipes" do
      sign_in(owner)
      get recipes_path

      expect(response.body).to include("Secret Stew")
    end
  end

  describe "GET /recipes/search" do
    it "does not leak another user's private recipe" do
      sign_in(other_user)
      get search_recipes_path, params: { query: "Secret" }

      expect(response.body).not_to include("Secret Stew")
    end

    it "finds the owner's own private recipe" do
      sign_in(owner)
      get search_recipes_path, params: { query: "Secret" }

      expect(response.body).to include("Secret Stew")
    end
  end

  describe "GET /recipes/:id/print" do
    it "prints a public recipe without signing in" do
      get print_recipe_path(public_recipe)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Public Pancakes")
      expect(response.body).to include("Ingredients")
    end

    it "leaves out the site navigation and footer" do
      get print_recipe_path(public_recipe)

      expect(response.body).not_to include("Back to Recipes")
      expect(response.body).not_to include("Built with")
    end

    it "refuses another user's private recipe" do
      sign_in(other_user)
      get print_recipe_path(private_recipe)

      expect(response).to have_http_status(:not_found)
    end

    it "prints the owner's own private recipe" do
      sign_in(owner)
      get print_recipe_path(private_recipe)

      expect(response).to have_http_status(:ok)
    end
  end

  describe "editing another user's private recipe" do
    before { sign_in(other_user) }

    it "cannot be opened" do
      get edit_recipe_path(private_recipe)

      expect(response).to have_http_status(:not_found)
    end

    it "cannot be updated" do
      patch recipe_path(private_recipe), params: { recipe: { title: "Hijacked" } }

      expect(response).to have_http_status(:not_found)
      expect(private_recipe.reload.title).to eq("Secret Stew")
    end

    it "cannot be destroyed" do
      expect {
        delete recipe_path(private_recipe)
      }.not_to change(Recipe, :count)

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "changing visibility" do
    let!(:owned_public) { create(:recipe, :public_recipe, user: owner, title: "Owned Public") }

    it "lets the owner make their recipe private" do
      sign_in(owner)
      patch recipe_path(owned_public), params: { recipe: { visibility: Recipe::PRIVATE } }

      expect(owned_public.reload).to be_private_recipe
    end

    it "ignores a visibility change from a non-owner" do
      sign_in(other_user)
      patch recipe_path(owned_public), params: { recipe: { visibility: Recipe::PRIVATE } }

      expect(owned_public.reload).to be_public_recipe
    end
  end

  describe "POST /recipes" do
    let(:category) { create(:category) }
    let(:attributes) do
      {
        title: "Owned Recipe",
        description: "A recipe with an owner",
        serves: 2,
        instructions: "Cook it",
        prep_time: "5 minutes",
        category_id: category.id,
        visibility: Recipe::PRIVATE,
        ingredients: [ { name: "Eggs", quantity: "2", unit: "pieces" } ],
        nutrition_calories: "200",
        nutrition_protein: "14g",
        nutrition_fat: "15g",
        nutrition_carbs: "2g",
        nutrition_fibre: "0g",
        nutrition_sugar: "1g",
        nutrition_sodium: "300mg"
      }
    end

    it "records the creator as the owner and honours the chosen visibility" do
      sign_in(owner)
      post recipes_path, params: { recipe: attributes }

      recipe = Recipe.find_by(title: "Owned Recipe")
      expect(recipe.user).to eq(owner)
      expect(recipe).to be_private_recipe
    end
  end
end

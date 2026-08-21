# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Favorites" do
  let(:user) { create(:user) }
  let(:owner) { create(:user) }
  let(:recipe) { create(:recipe, :public_recipe, title: "Public Pancakes") }
  let(:private_recipe) { create(:recipe, :private_recipe, user: owner, title: "Secret Stew") }

  describe "GET /favorites" do
    it "redirects a signed-out visitor to sign in" do
      get favorites_path

      expect(response).to redirect_to(sign_in_path)
    end

    it "lists only the current user's favorites" do
      create(:favorite, user: user, recipe: recipe)
      create(:favorite, user: owner, recipe: create(:recipe, title: "Someone Else's"))

      sign_in(user)
      get favorites_path

      expect(response.body).to include("Public Pancakes")
      expect(response.body).not_to include("Someone Else's")
    end

    it "hides a favorite that has since been made private by its owner" do
      create(:favorite, user: user, recipe: private_recipe)

      sign_in(user)
      get favorites_path

      expect(response.body).not_to include("Secret Stew")
    end
  end

  describe "POST /recipes/:recipe_id/favorite" do
    it "redirects a signed-out visitor to sign in" do
      expect {
        post recipe_favorite_path(recipe)
      }.not_to change(Favorite, :count)

      expect(response).to redirect_to(sign_in_path)
    end

    it "favorites the recipe for the current user" do
      sign_in(user)

      expect { post recipe_favorite_path(recipe) }.to change(Favorite, :count).by(1)
      expect(user.reload.favorited?(recipe)).to be true
    end

    it "is idempotent" do
      sign_in(user)
      post recipe_favorite_path(recipe)

      expect { post recipe_favorite_path(recipe) }.not_to change(Favorite, :count)
    end

    it "does not touch the basket" do
      sign_in(user)
      post recipe_favorite_path(recipe)

      expect(user.reload.in_basket?(recipe)).to be false
    end

    it "is refused on another user's private recipe" do
      sign_in(user)

      expect { post recipe_favorite_path(private_recipe) }.not_to change(Favorite, :count)
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "DELETE /recipes/:recipe_id/favorite" do
    it "removes only the current user's favorite" do
      mine = create(:favorite, user: user, recipe: recipe)
      theirs = create(:favorite, user: owner, recipe: recipe)

      sign_in(user)
      delete recipe_favorite_path(recipe)

      expect(Favorite.exists?(mine.id)).to be false
      expect(Favorite.exists?(theirs.id)).to be true
    end

    it "redirects a signed-out visitor to sign in" do
      create(:favorite, user: user, recipe: recipe)

      expect { delete recipe_favorite_path(recipe) }.not_to change(Favorite, :count)
      expect(response).to redirect_to(sign_in_path)
    end
  end

  describe "the favorite button on the recipe page" do
    it "is hidden from signed-out visitors" do
      get recipe_path(recipe)

      expect(response.body).not_to include(recipe_favorite_path(recipe))
    end

    it "offers to favorite, then to unfavorite" do
      sign_in(user)

      get recipe_path(recipe)
      expect(response.body).to include(">Favorite<")

      create(:favorite, user: user, recipe: recipe)
      get recipe_path(recipe)
      expect(response.body).to include(">Favorited<")
    end
  end
end

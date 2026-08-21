# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Shared recipe links" do
  let(:owner) { create(:user) }
  let(:other_user) { create(:user) }
  let(:public_recipe) { create(:recipe, :public_recipe, title: "Public Pancakes") }
  let(:private_recipe) { create(:recipe, :private_recipe, user: owner, title: "Secret Stew") }

  describe "GET /r/:token" do
    it "shows a public recipe while signed out" do
      get shared_recipe_path(public_recipe.public_token)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Public Pancakes")
    end

    it "is a capability link: it also reaches a private recipe" do
      get shared_recipe_path(private_recipe.public_token)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Secret Stew")
    end

    it "404s on an unknown token" do
      get shared_recipe_path("not-a-real-token")

      expect(response).to have_http_status(:not_found)
    end

    it "does not accept the numeric id in place of the token" do
      get shared_recipe_path(public_recipe.id)

      expect(response).to have_http_status(:not_found)
    end

    it "offers Open Graph tags for a public recipe" do
      get shared_recipe_path(public_recipe.public_token)

      expect(response.body).to include('property="og:title"')
      expect(response.body).to include('name="twitter:card"')
    end

    it "asks crawlers not to index a private recipe" do
      get shared_recipe_path(private_recipe.public_token)

      expect(response.body).to include('name="robots" content="noindex, nofollow"')
      expect(response.body).not_to include('property="og:title"')
    end

    it "links back to the full recipe page for someone who can see it" do
      sign_in(owner)
      get shared_recipe_path(private_recipe.public_token)

      expect(response.body).to include(recipe_path(private_recipe))
    end

    it "does not link to the full recipe page for someone who cannot" do
      sign_in(other_user)
      get shared_recipe_path(private_recipe.public_token)

      expect(response.body).not_to include("Open the full recipe page")
    end
  end

  describe "GET /r/:token/print" do
    it "prints a shared recipe while signed out" do
      get print_shared_recipe_path(public_recipe.public_token)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Public Pancakes")
      expect(response.body).not_to include("Built with")
    end

    it "404s on an unknown token" do
      get print_shared_recipe_path("nope")

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "the share UI on the recipe page" do
    it "offers the share link and social targets" do
      get recipe_path(public_recipe)

      expect(response.body).to include(public_recipe.public_token)
      expect(response.body).to include("Copy share link")
      expect(response.body).to include("facebook.com/sharer")
      expect(response.body).to include("x.com/intent")
      expect(response.body).to include("bsky.app/intent")
    end

    it "warns the owner that a private recipe's link works for anyone" do
      sign_in(owner)
      get recipe_path(private_recipe)

      expect(response.body).to include("Anyone you give this link to can read it")
    end
  end
end

# frozen_string_literal: true

require "rails_helper"

# These specs run with a real (per-example, in-memory) cache store - see
# spec/support/caching.rb. The trick used throughout to prove a fragment is
# genuinely being served from the cache is to mutate a record with
# `update_column`, which deliberately does *not* bump `updated_at` and so does
# not move the cache key: if the page still shows the old value, the cache is
# live. A normal `update!` then proves the fragment invalidates.
RSpec.describe "Fragment caching", :caching, type: :request do
  def capture_cache_writes
    keys = []
    subscriber = ->(*, payload) { keys << payload[:key] }
    ActiveSupport::Notifications.subscribed(subscriber, "cache_write.active_support") { yield }
    keys
  end

  def search_cache_writes(keys)
    keys.select { |key| key.to_s.start_with?("recipes/search") }
  end

  describe "recipes index" do
    let!(:category) { create(:category, name: "Brunch") }
    let!(:recipe) { create(:recipe, title: "Original Pancakes", category: category) }

    it "serves the recipe card from the cache and invalidates it when the recipe changes" do
      get recipes_path
      expect(response.body).to include("Original Pancakes")

      # No updated_at bump, so the key does not move: still the cached markup.
      recipe.update_column(:title, "Bypassed The Cache Key")
      get recipes_path
      expect(response.body).to include("Original Pancakes")
      expect(response.body).not_to include("Bypassed The Cache Key")

      recipe.update!(title: "Renamed Pancakes")
      get recipes_path
      expect(response.body).to include("Renamed Pancakes")
    end

    it "invalidates the collection fragment when a recipe is added" do
      get recipes_path
      expect(response.body).not_to include("Late Arrival")

      create(:recipe, title: "Late Arrival", category: category)

      get recipes_path
      expect(response.body).to include("Late Arrival")
    end

    it "invalidates the card when its category is renamed" do
      get recipes_path
      expect(response.body).to include("Brunch")

      category.update!(name: "Elevenses")

      get recipes_path
      expect(response.body).to include("Elevenses")
      expect(response.body).not_to include("Brunch")
    end
  end

  describe "recipe show" do
    let!(:category) { create(:category, name: "Supper") }
    let!(:recipe) { create(:recipe, title: "Original Stew", description: "Warming", category: category) }

    it "serves the recipe fragment from the cache and invalidates it on update" do
      get recipe_path(recipe)
      expect(response.body).to include("Original Stew")

      recipe.update_column(:title, "Bypassed The Cache Key")
      get recipe_path(recipe)
      expect(response.body).to include("Original Stew")

      recipe.update!(title: "Renamed Stew")
      get recipe_path(recipe)
      expect(response.body).to include("Renamed Stew")
    end

    it "invalidates the recipe fragment when its category is renamed" do
      get recipe_path(recipe)
      expect(response.body).to include("Supper")

      category.update!(name: "Dinner Party")

      get recipe_path(recipe)
      expect(response.body).to include("Dinner Party")
    end
  end

  describe "categories index" do
    let!(:category) { create(:category, name: "Baking") }

    it "invalidates the category fragment when one of its recipes changes" do
      recipe = create(:recipe, title: "Original Scones", category: category)

      get categories_path
      expect(response.body).to include("Original Scones")

      recipe.update_column(:title, "Bypassed The Cache Key")
      get categories_path
      expect(response.body).to include("Original Scones")

      # Recipe belongs_to :category, touch: true - so this moves the category's
      # cache version as well as the recipe's.
      recipe.update!(title: "Renamed Scones")
      get categories_path
      expect(response.body).to include("Renamed Scones")
    end

    it "invalidates the collection fragment when a category is created or renamed" do
      get categories_path
      expect(response.body).not_to include("Preserves")

      create(:category, name: "Preserves")
      get categories_path
      expect(response.body).to include("Preserves")

      category.update!(name: "Patisserie")
      get categories_path
      expect(response.body).to include("Patisserie")
      expect(response.body).not_to include("Baking")
    end
  end

  describe "cached category list" do
    it "invalidates on category create, update and destroy" do
      first = create(:category, name: "Soup")
      expect(Category.cached_list.map(&:name)).to eq([ "Soup" ])

      create(:category, name: "Salad")
      expect(Category.cached_list.map(&:name)).to eq([ "Salad", "Soup" ])

      first.update!(name: "Broth")
      expect(Category.cached_list.map(&:name)).to eq([ "Broth", "Salad" ])

      first.destroy!
      expect(Category.cached_list.map(&:name)).to eq([ "Salad" ])
    end
  end

  describe "search results" do
    let!(:category) { create(:category) }
    let!(:recipe) { create(:recipe, title: "Blueberry Pancakes", category: category) }

    it "caches the matching ids and reuses them for an equivalent query string" do
      keys = capture_cache_writes { get search_recipes_path(query: "pancakes") }
      expect(response.body).to include("Blueberry Pancakes")
      expect(search_cache_writes(keys)).not_to be_empty

      # Same query once normalised (trimmed, downcased, inner runs of spaces
      # collapsed) - served from the existing entry, so nothing is written.
      keys = capture_cache_writes { get search_recipes_path(query: "  PANCAKES  ") }
      expect(response.body).to include("Blueberry Pancakes")
      expect(search_cache_writes(keys)).to be_empty
    end

    it "invalidates when the recipe collection changes" do
      get search_recipes_path(query: "pancakes")
      expect(response.body).not_to include("Buttermilk Pancakes")

      create(:recipe, title: "Buttermilk Pancakes", category: category)

      get search_recipes_path(query: "pancakes")
      expect(response.body).to include("Buttermilk Pancakes")
    end

    it "does not cache the rendered page, only the ids" do
      keys = capture_cache_writes { get search_recipes_path(query: "pancakes") }
      cached = search_cache_writes(keys)

      expect(cached.size).to eq(1)
      expect(Rails.cache.read(cached.first)).to eq([ recipe.id ])
    end
  end
end

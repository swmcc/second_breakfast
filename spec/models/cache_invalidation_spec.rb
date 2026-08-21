# frozen_string_literal: true

require "rails_helper"

# The `touch: true` declarations that make the fragment caches bust correctly.
RSpec.describe "Cache invalidation touches" do
  describe "Recipe belongs_to :category" do
    let(:category) { create(:category) }

    it "touches the category when a recipe is created" do
      category.update_column(:updated_at, 1.day.ago)

      expect { create(:recipe, category: category) }
        .to change { category.reload.updated_at }
    end

    it "touches the category when a recipe is updated" do
      recipe = create(:recipe, category: category)
      category.update_column(:updated_at, 1.day.ago)

      expect { recipe.update!(title: "New title") }
        .to change { category.reload.updated_at }
    end

    it "touches the category when a recipe is destroyed" do
      recipe = create(:recipe, category: category)
      category.update_column(:updated_at, 1.day.ago)

      expect { recipe.destroy! }
        .to change { category.reload.updated_at }
    end

    it "touches both categories when a recipe is moved" do
      other = create(:category)
      recipe = create(:recipe, category: category)
      category.update_column(:updated_at, 1.day.ago)
      other.update_column(:updated_at, 1.day.ago)

      recipe.update!(category: other)

      expect(category.reload.updated_at).to be > 1.minute.ago
      expect(other.reload.updated_at).to be > 1.minute.ago
    end
  end

  describe "Basket belongs_to :user" do
    let(:user) { create(:user) }

    it "touches the user when a recipe is added to the basket" do
      user.update_column(:updated_at, 1.day.ago)

      expect { create(:basket, user: user) }
        .to change { user.reload.updated_at }
    end

    it "touches the user when a recipe is removed from the basket" do
      basket = create(:basket, user: user)
      user.update_column(:updated_at, 1.day.ago)

      expect { basket.destroy! }
        .to change { user.reload.updated_at }
    end

    it "moves the user's cache key so a cached count cannot go stale" do
      before_key = user.cache_key_with_version
      create(:basket, user: user)

      expect(user.reload.cache_key_with_version).not_to eq(before_key)
    end
  end

  describe "collection cache keys" do
    it "changes the recipes collection version on create, update and destroy" do
      recipe = create(:recipe)
      key = Recipe.all.cache_key_with_version

      recipe.update!(title: "Changed")
      expect(Recipe.all.cache_key_with_version).not_to eq(key)

      key = Recipe.all.cache_key_with_version
      create(:recipe)
      expect(Recipe.all.cache_key_with_version).not_to eq(key)

      key = Recipe.all.cache_key_with_version
      recipe.destroy!
      expect(Recipe.all.cache_key_with_version).not_to eq(key)
    end
  end
end

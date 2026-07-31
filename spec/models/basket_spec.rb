require "rails_helper"

RSpec.describe Basket do
  describe "validations" do
    # The model validates :recipe (not :recipe_id), so we test the behavior directly
    # rather than using shoulda-matchers which expects :recipe_id
    it "validates uniqueness of recipe scoped to user" do
      user = create(:user)
      recipe = create(:recipe)
      create(:basket, user: user, recipe: recipe)

      duplicate = build(:basket, user: user, recipe: recipe)
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:recipe]).to include("is already in your basket")
    end
  end

  describe "associations" do
    it { is_expected.to belong_to(:user) }
    it { is_expected.to belong_to(:recipe) }
  end

  describe "uniqueness constraint" do
    let(:user) { create(:user) }
    let(:recipe) { create(:recipe) }

    it "allows a user to add a recipe to their basket" do
      basket = Basket.new(user: user, recipe: recipe)
      expect(basket).to be_valid
    end

    it "prevents the same user from adding the same recipe twice" do
      create(:basket, user: user, recipe: recipe)
      duplicate = Basket.new(user: user, recipe: recipe)

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:recipe]).to include("is already in your basket")
    end

    it "allows different users to add the same recipe" do
      other_user = create(:user)
      create(:basket, user: user, recipe: recipe)

      other_basket = Basket.new(user: other_user, recipe: recipe)
      expect(other_basket).to be_valid
    end

    it "allows the same user to add different recipes" do
      other_recipe = create(:recipe)
      create(:basket, user: user, recipe: recipe)

      other_basket = Basket.new(user: user, recipe: other_recipe)
      expect(other_basket).to be_valid
    end
  end

  describe "associations behavior" do
    let(:user) { create(:user) }
    let(:recipe) { create(:recipe) }

    it "connects a user to their recipes through baskets" do
      create(:basket, user: user, recipe: recipe)

      expect(user.recipes).to include(recipe)
      expect(recipe.users).to include(user)
    end

    it "cannot be created without a user" do
      basket = Basket.new(user: nil, recipe: recipe)
      expect(basket).not_to be_valid
    end

    it "cannot be created without a recipe" do
      basket = Basket.new(user: user, recipe: nil)
      expect(basket).not_to be_valid
    end
  end

  describe "destroying baskets" do
    let(:basket) { create(:basket) }

    it "does not destroy the user when basket is destroyed" do
      user = basket.user
      basket.destroy
      expect(user.reload).to be_present
    end

    it "does not destroy the recipe when basket is destroyed" do
      recipe = basket.recipe
      basket.destroy
      expect(recipe.reload).to be_present
    end
  end

  describe "accessing through user" do
    let(:user) { create(:user) }
    let(:recipes) { create_list(:recipe, 3) }

    before do
      recipes.each { |recipe| create(:basket, user: user, recipe: recipe) }
    end

    it "user can access all their basket items" do
      expect(user.baskets.count).to eq(3)
    end

    it "user can access recipes through baskets" do
      expect(user.recipes.count).to eq(3)
      expect(user.recipes).to match_array(recipes)
    end
  end
end

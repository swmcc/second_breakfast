require "rails_helper"

RSpec.describe Favorite do
  describe "associations" do
    it { is_expected.to belong_to(:user) }
    it { is_expected.to belong_to(:recipe) }
  end

  describe "validations" do
    it "allows one favorite per user per recipe" do
      existing = create(:favorite)
      duplicate = build(:favorite, user: existing.user, recipe: existing.recipe)

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:user_id]).to include("has already favorited this recipe")
    end

    it "allows the same user to favorite different recipes" do
      user = create(:user)
      create(:favorite, user: user)

      expect(build(:favorite, user: user, recipe: create(:recipe))).to be_valid
    end
  end

  describe "independence from the basket" do
    let(:user) { create(:user) }
    let(:recipe) { create(:recipe) }

    it "does not add the recipe to the user's basket" do
      create(:favorite, user: user, recipe: recipe)

      expect(user.in_basket?(recipe)).to be false
      expect(user.baskets).to be_empty
    end

    it "does not affect the aggregated shopping list" do
      create(:favorite, user: user, recipe: recipe)

      expect(user.aggregated_ingredients).to be_empty
    end
  end

  describe "User#favorited?" do
    let(:user) { create(:user) }
    let(:recipe) { create(:recipe) }

    it "is false before favoriting" do
      expect(user.favorited?(recipe)).to be false
    end

    it "is true after favoriting" do
      create(:favorite, user: user, recipe: recipe)

      expect(user.reload.favorited?(recipe)).to be true
    end
  end

  describe "cascade deletes" do
    it "is destroyed with its recipe" do
      favorite = create(:favorite)

      expect { favorite.recipe.destroy }.to change(described_class, :count).by(-1)
    end

    it "is destroyed with its user" do
      favorite = create(:favorite)

      expect { favorite.user.destroy }.to change(described_class, :count).by(-1)
    end
  end
end

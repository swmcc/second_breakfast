require "rails_helper"

RSpec.describe User do
  describe "validations" do
    subject { build(:user) }

    it { is_expected.to validate_presence_of(:email) }
    it { is_expected.to validate_uniqueness_of(:email) }
    it { is_expected.to have_secure_password }
  end

  describe "associations" do
    it { is_expected.to have_many(:baskets).dependent(:destroy) }
    it { is_expected.to have_many(:recipes).through(:baskets) }
  end

  describe "#in_basket?" do
    let(:user) { create(:user) }
    let(:recipe) { create(:recipe) }

    context "when recipe is in the user's basket" do
      before { create(:basket, user: user, recipe: recipe) }

      it "returns true" do
        expect(user.in_basket?(recipe)).to be true
      end
    end

    context "when recipe is not in the user's basket" do
      it "returns false" do
        expect(user.in_basket?(recipe)).to be false
      end
    end

    context "when recipe is in another user's basket" do
      let(:other_user) { create(:user) }

      before { create(:basket, user: other_user, recipe: recipe) }

      it "returns false for the first user" do
        expect(user.in_basket?(recipe)).to be false
      end
    end
  end

  describe "#aggregated_ingredients" do
    let(:user) { create(:user) }
    let(:category) { create(:category) }

    context "with no recipes in basket" do
      it "returns an empty array" do
        expect(user.aggregated_ingredients).to eq([])
      end
    end

    context "with one recipe in basket" do
      let(:recipe) do
        create(:recipe, category: category, ingredients: [
          { "name" => "Flour", "quantity" => "2", "unit" => "cups" },
          { "name" => "Sugar", "quantity" => "1", "unit" => "cups" }
        ])
      end

      before { create(:basket, user: user, recipe: recipe) }

      it "returns the ingredients from that recipe" do
        result = user.aggregated_ingredients

        expect(result).to contain_exactly(
          { name: "Flour", quantity: 2.0, unit: "cups" },
          { name: "Sugar", quantity: 1.0, unit: "cups" }
        )
      end
    end

    context "with multiple recipes sharing ingredients" do
      let(:recipe1) do
        create(:recipe, category: category, ingredients: [
          { "name" => "Flour", "quantity" => "2", "unit" => "cups" },
          { "name" => "Eggs", "quantity" => "3", "unit" => "pieces" }
        ])
      end

      let(:recipe2) do
        create(:recipe, category: category, ingredients: [
          { "name" => "Flour", "quantity" => "1", "unit" => "cups" },
          { "name" => "Milk", "quantity" => "2", "unit" => "cups" }
        ])
      end

      before do
        create(:basket, user: user, recipe: recipe1)
        create(:basket, user: user, recipe: recipe2)
      end

      it "aggregates quantities of the same ingredient and unit" do
        result = user.aggregated_ingredients
        flour = result.find { |i| i[:name] == "Flour" }

        expect(flour[:quantity]).to eq(3.0)
        expect(flour[:unit]).to eq("cups")
      end

      it "keeps different ingredients separate" do
        result = user.aggregated_ingredients

        expect(result.map { |i| i[:name] }).to contain_exactly("Flour", "Eggs", "Milk")
      end
    end

    context "with same ingredient but different units" do
      let(:recipe1) do
        create(:recipe, category: category, ingredients: [
          { "name" => "Butter", "quantity" => "2", "unit" => "tbsp" }
        ])
      end

      let(:recipe2) do
        create(:recipe, category: category, ingredients: [
          { "name" => "Butter", "quantity" => "1", "unit" => "cups" }
        ])
      end

      before do
        create(:basket, user: user, recipe: recipe1)
        create(:basket, user: user, recipe: recipe2)
      end

      it "keeps them separate (does not convert units)" do
        result = user.aggregated_ingredients
        butter_items = result.select { |i| i[:name] == "Butter" }

        expect(butter_items.size).to eq(2)
        expect(butter_items).to contain_exactly(
          { name: "Butter", quantity: 2.0, unit: "tbsp" },
          { name: "Butter", quantity: 1.0, unit: "cups" }
        )
      end
    end
  end

  describe "#ingredients_list" do
    let(:user) { create(:user) }
    let(:category) { create(:category) }

    context "with no recipes in basket" do
      it "returns an empty array" do
        expect(user.ingredients_list).to eq([])
      end
    end

    context "with recipes in basket" do
      let(:recipe1) do
        create(:recipe, title: "Pancakes", category: category, ingredients: [
          { "name" => "Flour", "quantity" => "2", "unit" => "cups" }
        ])
      end

      let(:recipe2) do
        create(:recipe, title: "Omelette", category: category, ingredients: [
          { "name" => "Eggs", "quantity" => "3", "unit" => "pieces" }
        ])
      end

      before do
        create(:basket, user: user, recipe: recipe1)
        create(:basket, user: user, recipe: recipe2)
      end

      it "returns a list with recipe names and their ingredients" do
        result = user.ingredients_list

        expect(result).to contain_exactly(
          { recipe_name: "Pancakes", ingredients: recipe1.ingredients },
          { recipe_name: "Omelette", ingredients: recipe2.ingredients }
        )
      end
    end
  end

  describe "destroying a user" do
    let(:user) { create(:user) }
    let(:recipe) { create(:recipe) }

    before { create(:basket, user: user, recipe: recipe) }

    it "also destroys their baskets" do
      expect { user.destroy }.to change(Basket, :count).by(-1)
    end

    it "does not destroy the recipes" do
      expect { user.destroy }.not_to change(Recipe, :count)
    end
  end
end

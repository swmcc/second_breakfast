require "rails_helper"

RSpec.describe Category do
  describe "validations" do
    subject { build(:category) }

    it { is_expected.to validate_presence_of(:name) }
  end

  describe "associations" do
    it { is_expected.to have_many(:recipes) }
  end

  describe "with associated recipes" do
    let(:category) { create(:category) }

    before do
      create_list(:recipe, 3, category: category)
    end

    it "can access its recipes" do
      expect(category.recipes.count).to eq(3)
    end

    it "recipes belong to the category" do
      category.recipes.each do |recipe|
        expect(recipe.category).to eq(category)
      end
    end
  end

  describe "creating categories" do
    it "can create a category with just a name" do
      category = Category.create!(name: "Desserts")
      expect(category).to be_persisted
      expect(category.name).to eq("Desserts")
    end

    it "cannot create a category without a name" do
      category = Category.new(name: nil)
      expect(category).not_to be_valid
      expect(category.errors[:name]).to include("can't be blank")
    end

    it "cannot create a category with an empty name" do
      category = Category.new(name: "")
      expect(category).not_to be_valid
    end
  end

  describe "destroying a category" do
    context "when category has recipes" do
      it "raises a foreign key violation error" do
        # The database has a foreign key constraint preventing deletion
        # of categories that have recipes. This is correct behavior
        # to maintain data integrity.
        category = create(:category)
        create(:recipe, category: category)

        expect { category.destroy! }.to raise_error(ActiveRecord::InvalidForeignKey)
      end

      # Note: Consider adding `dependent: :restrict_with_error` to the model
      # to provide a user-friendly error message instead of a database error
    end

    context "when category has no recipes" do
      it "can be destroyed" do
        category = create(:category)
        expect(category.recipes).to be_empty

        category.destroy!
        expect(Category.find_by(id: category.id)).to be_nil
      end
    end
  end
end

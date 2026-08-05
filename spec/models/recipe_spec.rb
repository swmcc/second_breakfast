require "rails_helper"

RSpec.describe Recipe do
  describe "validations" do
    subject { build(:recipe) }

    it { is_expected.to validate_presence_of(:title) }
    it { is_expected.to validate_presence_of(:description) }
    it { is_expected.to validate_presence_of(:serves) }
    it { is_expected.to validate_presence_of(:prep_time) }
    it { is_expected.to validate_presence_of(:ingredients) }
    it { is_expected.to validate_presence_of(:nutrition) }

    # ActionText validation - instructions presence is validated but shoulda-matchers
    # doesn't handle rich text well, so we test it manually
    describe "instructions validation" do
      it "is invalid without instructions" do
        recipe = build(:recipe)
        recipe.instructions = nil
        expect(recipe).not_to be_valid
        expect(recipe.errors[:instructions]).to include("can't be blank")
      end

      it "is valid with instructions" do
        recipe = build(:recipe)
        recipe.instructions = "Mix all ingredients and bake."
        expect(recipe).to be_valid
      end
    end

    describe "image validation" do
      it "accepts supported image content types up to 5 MB" do
        recipe = build(:recipe)
        recipe.image.attach(io: StringIO.new("image data"), filename: "image.webp", content_type: "image/webp")

        expect(recipe).to be_valid
      end

      it "rejects unsupported image content types" do
        recipe = build(:recipe)
        recipe.image.attach(io: StringIO.new("document"), filename: "document.pdf", content_type: "application/pdf")

        expect(recipe).not_to be_valid
        expect(recipe.errors[:image]).to include("must be a PNG, JPEG, WebP, or GIF")
      end

      it "rejects images larger than 5 MB" do
        blob = ActiveStorage::Blob.create_and_upload!(
          io: StringIO.new("a" * (5.megabytes + 1)),
          filename: "large.jpg",
          content_type: "image/jpeg"
        )
        recipe = build(:recipe)
        recipe.image.attach(blob)

        expect(recipe).not_to be_valid
        expect(recipe.errors[:image]).to include("must be smaller than 5 MB")
      end
    end
  end

  describe "instruction sanitization" do
    it "removes executable script tags when rendered" do
      recipe = build(:recipe, instructions: "Prepare safely<script>alert(1)</script>")

      expect(recipe.instructions.to_s).not_to include("<script")
    end
  end

  describe "associations" do
    it { is_expected.to belong_to(:category) }
    it { is_expected.to have_many(:baskets).dependent(:destroy) }
    it { is_expected.to have_many(:users).through(:baskets) }
    it { is_expected.to have_rich_text(:instructions) }
    it { is_expected.to have_one_attached(:image) }
  end

  describe "nutrition format validation" do
    let(:category) { create(:category) }
    let(:valid_nutrition) do
      {
        "calories" => "300",
        "protein" => "20g",
        "fat" => "15g",
        "carbs" => "30g",
        "fibre" => "5g",
        "sugar" => "10g",
        "sodium" => "400mg"
      }
    end

    it "is valid with all required nutrition fields" do
      recipe = build(:recipe, category: category, nutrition: valid_nutrition)
      expect(recipe).to be_valid
    end

    it "is invalid when nutrition is not a hash" do
      recipe = build(:recipe, category: category, nutrition: "not a hash")
      expect(recipe).not_to be_valid
      expect(recipe.errors[:nutrition]).to include(/must include all required fields/)
    end

    it "is invalid when nutrition is nil" do
      recipe = build(:recipe, category: category, nutrition: nil)
      expect(recipe).not_to be_valid
    end

    context "with missing nutrition fields" do
      %w[calories protein fat carbs fibre sugar sodium].each do |field|
        it "is invalid without #{field}" do
          incomplete_nutrition = valid_nutrition.except(field)
          recipe = build(:recipe, category: category, nutrition: incomplete_nutrition)

          expect(recipe).not_to be_valid
          expect(recipe.errors[:nutrition]).to include(/must include all required fields/)
        end
      end
    end

    it "is valid with extra nutrition fields" do
      extra_nutrition = valid_nutrition.merge("cholesterol" => "50mg")
      recipe = build(:recipe, category: category, nutrition: extra_nutrition)
      expect(recipe).to be_valid
    end
  end

  describe "destroying a recipe" do
    let(:recipe) { create(:recipe) }
    let(:user) { create(:user) }

    before { create(:basket, user: user, recipe: recipe) }

    it "also destroys associated baskets" do
      expect { recipe.destroy }.to change(Basket, :count).by(-1)
    end

    it "does not destroy the user" do
      expect { recipe.destroy }.not_to change(User, :count)
    end

    it "does not destroy the category" do
      expect { recipe.destroy }.not_to change(Category, :count)
    end
  end

  describe "category association" do
    it "cannot be saved without a category" do
      recipe = build(:recipe, category: nil)
      expect(recipe).not_to be_valid
    end

    it "belongs to the correct category" do
      breakfast = create(:category, name: "Breakfast")
      recipe = create(:recipe, category: breakfast)

      expect(recipe.category).to eq(breakfast)
      expect(recipe.category.name).to eq("Breakfast")
    end
  end

  describe "ingredients structure" do
    let(:recipe) { create(:recipe) }

    it "stores ingredients as an array of hashes" do
      expect(recipe.ingredients).to be_an(Array)
      expect(recipe.ingredients.first).to be_a(Hash)
    end

    it "each ingredient has name, quantity, and unit" do
      recipe = create(:recipe, ingredients: [
        { "name" => "Salt", "quantity" => "1", "unit" => "tsp" }
      ])

      ingredient = recipe.ingredients.first
      expect(ingredient).to include("name", "quantity", "unit")
    end
  end
end

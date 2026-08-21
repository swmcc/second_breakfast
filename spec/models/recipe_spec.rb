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

  describe "sharing and visibility" do
    describe "associations" do
      it { is_expected.to belong_to(:user).optional }
      it { is_expected.to have_many(:ratings).dependent(:destroy) }
      it { is_expected.to have_many(:reviews).dependent(:destroy) }
      it { is_expected.to have_many(:favorites).dependent(:destroy) }
    end

    describe "visibility" do
      it "defaults to public so pre-existing recipes stay readable" do
        expect(create(:recipe).visibility).to eq(Recipe::PUBLIC)
      end

      it "rejects an unknown visibility" do
        recipe = build(:recipe, visibility: "unlisted")

        expect(recipe).not_to be_valid
        expect(recipe.errors[:visibility]).to be_present
      end

      it "answers #public_recipe? and #private_recipe?" do
        expect(build(:recipe, :public_recipe)).to be_public_recipe
        expect(build(:recipe, :private_recipe)).to be_private_recipe
      end
    end

    describe ".visible_to" do
      let(:owner) { create(:user) }
      let(:other) { create(:user) }
      let!(:public_recipe) { create(:recipe, :public_recipe) }
      let!(:own_private) { create(:recipe, :private_recipe, user: owner) }
      let!(:other_private) { create(:recipe, :private_recipe, user: other) }

      it "returns only public recipes when signed out" do
        expect(described_class.visible_to(nil)).to contain_exactly(public_recipe)
      end

      it "returns public recipes plus the user's own private ones" do
        expect(described_class.visible_to(owner)).to contain_exactly(public_recipe, own_private)
      end

      it "never returns another user's private recipe" do
        expect(described_class.visible_to(other)).not_to include(own_private)
      end

      it "composes with other relation methods" do
        relation = described_class.includes(:category).order(created_at: :desc).visible_to(owner)

        expect(relation).to contain_exactly(public_recipe, own_private)
      end
    end

    describe "#visible_to?" do
      let(:owner) { create(:user) }

      it "is true for anyone on a public recipe" do
        expect(create(:recipe, :public_recipe).visible_to?(nil)).to be true
      end

      it "is true for the owner of a private recipe" do
        expect(create(:recipe, :private_recipe, user: owner).visible_to?(owner)).to be true
      end

      it "is false for another user on a private recipe" do
        expect(create(:recipe, :private_recipe, user: owner).visible_to?(create(:user))).to be false
      end

      it "is false when signed out on a private recipe" do
        expect(create(:recipe, :private_recipe, user: owner).visible_to?(nil)).to be false
      end
    end

    describe "#editable_by?" do
      let(:owner) { create(:user) }

      it "is true for the owner" do
        expect(create(:recipe, user: owner).editable_by?(owner)).to be true
      end

      it "is false for another user" do
        expect(create(:recipe, user: owner).editable_by?(create(:user))).to be false
      end

      it "is true for any signed-in user on an unowned legacy recipe" do
        expect(create(:recipe).editable_by?(create(:user))).to be true
      end

      it "is false when signed out" do
        expect(create(:recipe).editable_by?(nil)).to be false
      end
    end

    describe "#public_token" do
      it "is generated on create" do
        expect(create(:recipe).public_token).to be_present
      end

      it "is unique per recipe" do
        tokens = create_list(:recipe, 3).map(&:public_token)

        expect(tokens.uniq.size).to eq(3)
      end

      it "is long enough not to be guessable" do
        expect(create(:recipe).public_token.length).to be >= 24
      end
    end

    describe "ratings aggregation" do
      let(:recipe) { create(:recipe) }

      it "has no average before anyone rates it" do
        expect(recipe.average_rating).to be_nil
        expect(recipe.ratings_count).to eq(0)
      end

      it "averages the rating values" do
        create(:rating, recipe: recipe, value: 5)
        create(:rating, recipe: recipe, value: 2)

        expect(recipe.average_rating).to eq(3.5)
        expect(recipe.ratings_count).to eq(2)
      end

      it "finds a given user's rating" do
        user = create(:user)
        rating = create(:rating, recipe: recipe, user: user, value: 4)

        expect(recipe.rating_by(user)).to eq(rating)
        expect(recipe.rating_by(create(:user))).to be_nil
        expect(recipe.rating_by(nil)).to be_nil
      end
    end

    describe "ownership after the owner deletes their account" do
      it "keeps the recipe but clears the owner" do
        owner = create(:user)
        recipe = create(:recipe, user: owner)

        expect { owner.destroy }.not_to change(described_class, :count)
        expect(recipe.reload.user_id).to be_nil
      end
    end
  end
end

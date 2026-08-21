require "rails_helper"

RSpec.describe Rating do
  describe "associations" do
    it { is_expected.to belong_to(:user) }
    it { is_expected.to belong_to(:recipe) }
  end

  describe "validations" do
    subject { build(:rating) }

    it { is_expected.to validate_presence_of(:value) }

    it "accepts every value from 1 to 5" do
      (1..5).each do |value|
        expect(build(:rating, value: value)).to be_valid
      end
    end

    it "rejects a value below 1" do
      rating = build(:rating, value: 0)

      expect(rating).not_to be_valid
      expect(rating.errors[:value]).to include("must be between 1 and 5")
    end

    it "rejects a value above 5" do
      rating = build(:rating, value: 6)

      expect(rating).not_to be_valid
      expect(rating.errors[:value]).to include("must be between 1 and 5")
    end

    it "allows one rating per user per recipe" do
      existing = create(:rating)
      duplicate = build(:rating, user: existing.user, recipe: existing.recipe)

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:user_id]).to include("has already rated this recipe")
    end

    it "allows the same user to rate different recipes" do
      user = create(:user)
      create(:rating, user: user)

      expect(build(:rating, user: user, recipe: create(:recipe))).to be_valid
    end
  end

  describe "cascade deletes" do
    it "is destroyed with its recipe" do
      rating = create(:rating)

      expect { rating.recipe.destroy }.to change(described_class, :count).by(-1)
    end

    it "is destroyed with its user" do
      rating = create(:rating)

      expect { rating.user.destroy }.to change(described_class, :count).by(-1)
    end
  end
end

require "rails_helper"

RSpec.describe Review do
  describe "associations" do
    it { is_expected.to belong_to(:user) }
    it { is_expected.to belong_to(:recipe) }
  end

  describe "validations" do
    subject { build(:review) }

    it { is_expected.to validate_presence_of(:body) }
    it { is_expected.to validate_length_of(:body).is_at_most(Review::MAX_BODY_LENGTH) }

    it "allows a user to review the same recipe more than once" do
      existing = create(:review)

      expect(build(:review, user: existing.user, recipe: existing.recipe)).to be_valid
    end
  end

  describe "#editable_by?" do
    let(:review) { create(:review) }

    it "is true for the author" do
      expect(review.editable_by?(review.user)).to be true
    end

    it "is false for another user" do
      expect(review.editable_by?(create(:user))).to be false
    end

    it "is false when signed out" do
      expect(review.editable_by?(nil)).to be false
    end
  end

  describe ".newest_first" do
    it "orders newest to oldest" do
      recipe = create(:recipe)
      older = create(:review, recipe: recipe, created_at: 2.days.ago)
      newer = create(:review, recipe: recipe, created_at: 1.hour.ago)

      expect(recipe.reviews.newest_first.to_a).to eq([ newer, older ])
    end
  end

  describe "cascade deletes" do
    it "is destroyed with its recipe" do
      review = create(:review)

      expect { review.recipe.destroy }.to change(described_class, :count).by(-1)
    end

    it "is destroyed with its user" do
      review = create(:review)

      expect { review.user.destroy }.to change(described_class, :count).by(-1)
    end
  end
end

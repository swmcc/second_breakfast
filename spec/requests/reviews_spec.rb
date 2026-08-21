# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Reviews" do
  let(:author) { create(:user) }
  let(:other_user) { create(:user) }
  let(:owner) { create(:user) }
  let(:recipe) { create(:recipe, :public_recipe) }
  let(:private_recipe) { create(:recipe, :private_recipe, user: owner) }

  describe "POST /recipes/:recipe_id/reviews" do
    context "when signed out" do
      it "redirects to sign in and creates nothing" do
        expect {
          post recipe_reviews_path(recipe), params: { review: { body: "Lovely" } }
        }.not_to change(Review, :count)

        expect(response).to redirect_to(sign_in_path)
      end
    end

    context "when signed in" do
      before { sign_in(author) }

      it "creates a review attributed to the current user" do
        expect {
          post recipe_reviews_path(recipe), params: { review: { body: "Lovely" } }
        }.to change(Review, :count).by(1)

        expect(Review.last.user).to eq(author)
        expect(Review.last.recipe).to eq(recipe)
      end

      it "rejects an empty body" do
        post recipe_reviews_path(recipe), params: { review: { body: "" } }

        expect(Review.count).to eq(0)
        expect(flash[:alert]).to be_present
      end
    end

    context "on a private recipe" do
      it "is refused for another user" do
        sign_in(other_user)

        expect {
          post recipe_reviews_path(private_recipe), params: { review: { body: "Sneaky" } }
        }.not_to change(Review, :count)

        expect(response).to have_http_status(:not_found)
      end

      it "is allowed for the owner" do
        sign_in(owner)

        expect {
          post recipe_reviews_path(private_recipe), params: { review: { body: "Mine" } }
        }.to change(Review, :count).by(1)
      end
    end
  end

  describe "editing a review" do
    let!(:review) { create(:review, user: author, recipe: recipe, body: "First take") }

    it "lets the author open the edit form" do
      sign_in(author)
      get edit_recipe_review_path(recipe, review)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("First take")
    end

    it "does not let another user open the edit form" do
      sign_in(other_user)
      get edit_recipe_review_path(recipe, review)

      expect(response).to have_http_status(:not_found)
    end

    it "redirects a signed-out visitor to sign in" do
      get edit_recipe_review_path(recipe, review)

      expect(response).to redirect_to(sign_in_path)
    end

    it "lets the author update their review" do
      sign_in(author)
      patch recipe_review_path(recipe, review), params: { review: { body: "Second take" } }

      expect(review.reload.body).to eq("Second take")
    end

    it "does not let another user update it" do
      sign_in(other_user)
      patch recipe_review_path(recipe, review), params: { review: { body: "Hijacked" } }

      expect(response).to have_http_status(:not_found)
      expect(review.reload.body).to eq("First take")
    end

    it "re-renders the form when the update is invalid" do
      sign_in(author)
      patch recipe_review_path(recipe, review), params: { review: { body: "" } }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(review.reload.body).to eq("First take")
    end
  end

  describe "deleting a review" do
    let!(:review) { create(:review, user: author, recipe: recipe) }

    it "lets the author delete it" do
      sign_in(author)

      expect { delete recipe_review_path(recipe, review) }.to change(Review, :count).by(-1)
    end

    it "does not let another user delete it" do
      sign_in(other_user)

      expect { delete recipe_review_path(recipe, review) }.not_to change(Review, :count)
      expect(response).to have_http_status(:not_found)
    end

    it "does not let a signed-out visitor delete it" do
      expect { delete recipe_review_path(recipe, review) }.not_to change(Review, :count)
      expect(response).to redirect_to(sign_in_path)
    end
  end

  describe "the review list on the recipe page" do
    it "lists reviews newest first" do
      create(:review, recipe: recipe, body: "Older one", created_at: 2.days.ago)
      create(:review, recipe: recipe, body: "Newer one", created_at: 1.hour.ago)

      get recipe_path(recipe)

      expect(response.body.index("Newer one")).to be < response.body.index("Older one")
    end

    it "offers edit and delete only to the review's author" do
      review = create(:review, user: author, recipe: recipe)

      sign_in(author)
      get recipe_path(recipe)
      expect(response.body).to include(edit_recipe_review_path(recipe, review))

      sign_out
      sign_in(other_user)
      get recipe_path(recipe)
      expect(response.body).not_to include(edit_recipe_review_path(recipe, review))
    end
  end
end

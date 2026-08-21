# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Ratings" do
  let(:owner) { create(:user) }
  let(:other_user) { create(:user) }
  let(:recipe) { create(:recipe, :public_recipe) }
  let(:private_recipe) { create(:recipe, :private_recipe, user: owner) }

  describe "POST /recipes/:recipe_id/rating" do
    context "when signed out" do
      it "redirects to sign in" do
        post recipe_rating_path(recipe), params: { rating: { value: 4 } }

        expect(response).to redirect_to(sign_in_path)
      end

      it "does not create a rating" do
        expect {
          post recipe_rating_path(recipe), params: { rating: { value: 4 } }
        }.not_to change(Rating, :count)
      end
    end

    context "when signed in" do
      before { sign_in(other_user) }

      it "creates a rating" do
        expect {
          post recipe_rating_path(recipe), params: { rating: { value: 4 } }
        }.to change(Rating, :count).by(1)

        expect(recipe.reload.average_rating).to eq(4.0)
      end

      it "updates the existing rating rather than adding another" do
        create(:rating, user: other_user, recipe: recipe, value: 2)

        expect {
          post recipe_rating_path(recipe), params: { rating: { value: 5 } }
        }.not_to change(Rating, :count)

        expect(recipe.reload.average_rating).to eq(5.0)
      end

      it "rejects an out-of-range value" do
        post recipe_rating_path(recipe), params: { rating: { value: 9 } }

        expect(Rating.count).to eq(0)
        expect(flash[:alert]).to include("between 1 and 5")
      end
    end

    context "on a private recipe" do
      it "is refused for another user" do
        sign_in(other_user)

        expect {
          post recipe_rating_path(private_recipe), params: { rating: { value: 4 } }
        }.not_to change(Rating, :count)

        expect(response).to have_http_status(:not_found)
      end

      it "is allowed for the owner" do
        sign_in(owner)

        expect {
          post recipe_rating_path(private_recipe), params: { rating: { value: 4 } }
        }.to change(Rating, :count).by(1)
      end
    end
  end

  describe "DELETE /recipes/:recipe_id/rating" do
    it "removes only the current user's rating" do
      mine = create(:rating, user: other_user, recipe: recipe)
      theirs = create(:rating, user: owner, recipe: recipe)
      sign_in(other_user)

      delete recipe_rating_path(recipe)

      expect(Rating.exists?(mine.id)).to be false
      expect(Rating.exists?(theirs.id)).to be true
    end

    it "redirects to sign in when signed out" do
      delete recipe_rating_path(recipe)

      expect(response).to redirect_to(sign_in_path)
    end
  end

  describe "the rating UI" do
    it "invites signed-out visitors to sign in" do
      get recipe_path(recipe)

      expect(response.body).to include("to rate this recipe")
    end

    it "shows the average once a recipe has been rated" do
      create(:rating, recipe: recipe, value: 5)
      create(:rating, recipe: recipe, value: 4)

      get recipe_path(recipe)

      expect(response.body).to include("4.5")
      expect(response.body).to include("2 ratings")
    end
  end
end

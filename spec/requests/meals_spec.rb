require "rails_helper"

RSpec.describe "Meals" do
  let(:user) { create(:user) }
  let(:recipe) { create(:recipe) }

  describe "GET /meal-plan" do
    context "when authenticated" do
      before { sign_in(user) }

      it "returns success" do
        get meal_plan_path
        expect(response).to have_http_status(:success)
      end

      it "displays empty state when no meals planned" do
        get meal_plan_path
        expect(response.body).to include("No meals planned")
      end

      context "with meals in the plan" do
        let!(:basket) { create(:basket, user: user, recipe: recipe) }

        it "displays the recipe" do
          get meal_plan_path
          expect(response.body).to include(recipe.title)
        end

        it "displays serves information" do
          get meal_plan_path
          expect(response.body).to include("Serves #{recipe.serves}")
        end

        it "displays prep time" do
          get meal_plan_path
          expect(response.body).to include(recipe.prep_time)
        end

        it "displays shopping list section" do
          get meal_plan_path
          expect(response.body).to include("Shopping List")
        end
      end
    end

    context "when not authenticated" do
      it "redirects to login" do
        get meal_plan_path
        expect(response).to redirect_to(sign_in_path)
      end
    end
  end

  describe "DELETE /meals/:id" do
    context "when authenticated" do
      before { sign_in(user) }

      context "when recipe is in meal plan" do
        let!(:basket) { create(:basket, user: user, recipe: recipe) }

        it "removes the recipe from meal plan" do
          expect {
            delete meal_path(basket), params: { recipe_id: recipe.id }
          }.to change(user.baskets, :count).by(-1)
        end

        it "redirects to meal plan" do
          delete meal_path(basket), params: { recipe_id: recipe.id }
          expect(response).to redirect_to(meal_plan_path)
        end

        it "shows success notice" do
          delete meal_path(basket), params: { recipe_id: recipe.id }
          follow_redirect!
          expect(response.body).to include("Recipe removed from your meal plan!")
        end
      end
    end

    context "when not authenticated" do
      let!(:basket) { create(:basket, user: user, recipe: recipe) }

      it "redirects to login" do
        delete meal_path(basket), params: { recipe_id: recipe.id }
        expect(response).to redirect_to(sign_in_path)
      end
    end
  end

  describe "POST /meals/toggle" do
    context "when authenticated" do
      before { sign_in(user) }

      context "when recipe is not in meal plan" do
        it "adds the recipe to meal plan" do
          expect {
            post toggle_meal_path, params: { recipe_id: recipe.id }
          }.to change(user.baskets, :count).by(1)
        end

        it "shows add message" do
          post toggle_meal_path, params: { recipe_id: recipe.id }
          follow_redirect!
          expect(response.body).to include("Recipe added to your meal plan!")
        end
      end

      context "when recipe is already in meal plan" do
        before { create(:basket, user: user, recipe: recipe) }

        it "removes the recipe from meal plan" do
          expect {
            post toggle_meal_path, params: { recipe_id: recipe.id }
          }.to change(user.baskets, :count).by(-1)
        end

        it "shows remove message" do
          post toggle_meal_path, params: { recipe_id: recipe.id }
          follow_redirect!
          expect(response.body).to include("Recipe removed from your meal plan!")
        end
      end

      context "with idempotent behavior" do
        it "toggling twice returns to original state" do
          # Add
          post toggle_meal_path, params: { recipe_id: recipe.id }
          expect(user.baskets.count).to eq(1)

          # Remove
          post toggle_meal_path, params: { recipe_id: recipe.id }
          expect(user.baskets.count).to eq(0)

          # Add again
          post toggle_meal_path, params: { recipe_id: recipe.id }
          expect(user.baskets.count).to eq(1)
        end
      end

      context "with non-existent recipe" do
        it "redirects with an error" do
          post toggle_meal_path, params: { recipe_id: 999999 }
          expect(response).to redirect_to(recipes_path)
          expect(flash[:alert]).to eq("Recipe not found")
        end
      end
    end

    context "when not authenticated" do
      it "redirects to login" do
        post toggle_meal_path, params: { recipe_id: recipe.id }
        expect(response).to redirect_to(sign_in_path)
      end
    end
  end
end

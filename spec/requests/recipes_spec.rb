require "rails_helper"

RSpec.describe "Recipes" do
  let(:user) { create(:user) }
  let(:category) { create(:category) }
  let(:valid_attributes) do
    {
      title: "Scrambled Eggs",
      description: "Simple and delicious scrambled eggs",
      serves: 2,
      instructions: "Beat eggs, cook in pan, season to taste",
      prep_time: "10 minutes",
      category_id: category.id,
      ingredients: [
        { name: "Eggs", quantity: "4", unit: "pieces" },
        { name: "Butter", quantity: "1", unit: "tbsp" }
      ],
      nutrition_calories: "200",
      nutrition_protein: "14g",
      nutrition_fat: "15g",
      nutrition_carbs: "2g",
      nutrition_fibre: "0g",
      nutrition_sugar: "1g",
      nutrition_sodium: "300mg"
    }
  end

  let(:invalid_attributes) do
    { title: "", description: "", serves: nil }
  end

  describe "GET /recipes" do
    it "returns a successful response" do
      get recipes_path
      expect(response).to have_http_status(:ok)
    end

    it "displays all recipes" do
      recipes = create_list(:recipe, 3)
      get recipes_path

      recipes.each do |recipe|
        expect(response.body).to include(recipe.title)
      end
    end
  end

  describe "GET /recipes/:id" do
    let(:recipe) { create(:recipe) }

    it "returns a successful response" do
      get recipe_path(recipe)
      expect(response).to have_http_status(:ok)
    end

    it "displays the recipe details" do
      get recipe_path(recipe)

      expect(response.body).to include(recipe.title)
      expect(response.body).to include(recipe.description)
    end
  end

  describe "GET /recipes/new" do
    context "when authenticated" do
      before { sign_in(user) }

      it "returns a successful response" do
        get new_recipe_path
        expect(response).to have_http_status(:ok)
      end
    end

    context "when not authenticated" do
      it "redirects to login" do
        get new_recipe_path
        expect(response).to redirect_to(sign_in_path)
      end
    end
  end

  describe "POST /recipes" do
    context "when authenticated" do
      before { sign_in(user) }

      context "with valid parameters" do
        it "creates a new recipe" do
          expect {
            post recipes_path, params: { recipe: valid_attributes }
          }.to change(Recipe, :count).by(1)
        end

        it "redirects to the created recipe" do
          post recipes_path, params: { recipe: valid_attributes }
          expect(response).to redirect_to(Recipe.last)
        end
      end

      context "with invalid parameters" do
        it "does not create a new recipe" do
          expect {
            post recipes_path, params: { recipe: invalid_attributes }
          }.not_to change(Recipe, :count)
        end

        it "returns unprocessable entity status" do
          post recipes_path, params: { recipe: invalid_attributes }
          expect(response).to have_http_status(:unprocessable_entity)
        end
      end
    end

    context "when not authenticated" do
      it "redirects to login" do
        post recipes_path, params: { recipe: valid_attributes }
        expect(response).to redirect_to(sign_in_path)
      end

      it "does not create a recipe" do
        expect {
          post recipes_path, params: { recipe: valid_attributes }
        }.not_to change(Recipe, :count)
      end
    end
  end

  describe "GET /recipes/:id/edit" do
    let(:recipe) { create(:recipe) }

    context "when authenticated" do
      before { sign_in(user) }

      it "returns a successful response" do
        get edit_recipe_path(recipe)
        expect(response).to have_http_status(:ok)
      end
    end

    context "when not authenticated" do
      it "redirects to login" do
        get edit_recipe_path(recipe)
        expect(response).to redirect_to(sign_in_path)
      end
    end
  end

  describe "PATCH /recipes/:id" do
    let(:recipe) { create(:recipe) }
    let(:new_attributes) { { title: "Updated Recipe Title" } }

    context "when authenticated" do
      before { sign_in(user) }

      context "with valid parameters" do
        it "updates the recipe" do
          patch recipe_path(recipe), params: { recipe: new_attributes }
          recipe.reload
          expect(recipe.title).to eq("Updated Recipe Title")
        end

        it "redirects to the recipe" do
          patch recipe_path(recipe), params: { recipe: new_attributes }
          expect(response).to redirect_to(recipe)
        end
      end

      context "with invalid parameters" do
        it "returns unprocessable entity status" do
          patch recipe_path(recipe), params: { recipe: { title: "" } }
          expect(response).to have_http_status(:unprocessable_entity)
        end
      end
    end

    context "when not authenticated" do
      it "redirects to login" do
        patch recipe_path(recipe), params: { recipe: new_attributes }
        expect(response).to redirect_to(sign_in_path)
      end
    end
  end

  describe "DELETE /recipes/:id" do
    let!(:recipe) { create(:recipe) }

    context "when authenticated" do
      before { sign_in(user) }

      it "destroys the recipe" do
        expect {
          delete recipe_path(recipe)
        }.to change(Recipe, :count).by(-1)
      end

      it "redirects to recipes index" do
        delete recipe_path(recipe)
        expect(response).to redirect_to(recipes_path)
      end
    end

    context "when not authenticated" do
      it "redirects to login" do
        delete recipe_path(recipe)
        expect(response).to redirect_to(sign_in_path)
      end

      it "does not destroy the recipe" do
        expect {
          delete recipe_path(recipe)
        }.not_to change(Recipe, :count)
      end
    end
  end

  describe "GET /recipes/search" do
    let!(:pancakes) { create(:recipe, title: "Fluffy Pancakes") }
    let!(:omelette) { create(:recipe, title: "Cheese Omelette") }

    context "with matching query" do
      it "returns recipes matching the title" do
        get search_recipes_path, params: { query: "pancakes" }

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Fluffy Pancakes")
        expect(response.body).not_to include("Cheese Omelette")
      end

      it "is case insensitive" do
        get search_recipes_path, params: { query: "PANCAKES" }

        expect(response.body).to include("Fluffy Pancakes")
      end

      it "matches recipe descriptions" do
        create(:recipe, title: "Mystery Bowl", description: "A quiet zorblewaffle of a breakfast")

        get search_recipes_path, params: { query: "zorblewaffle" }

        expect(response.body).to include("Mystery Bowl")
      end

      it "matches the ActionText instructions body" do
        create(:recipe, title: "Slow Stew", instructions: "Simmer the zorblewaffle for an hour")

        get search_recipes_path, params: { query: "zorblewaffle" }

        expect(response.body).to include("Slow Stew")
      end
    end

    context "with ingredient query" do
      let!(:egg_recipe) do
        create(:recipe, title: "Egg Dish", ingredients: [
          { "name" => "Eggs", "quantity" => "2", "unit" => "pieces" }
        ])
      end

      it "searches in ingredients" do
        get search_recipes_path, params: { query: "Eggs" }

        expect(response.body).to include("Egg Dish")
      end

      it "filters by ingredient name without a keyword query" do
        get search_recipes_path, params: { ingredient: "eggs" }

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Egg Dish")
        expect(response.body).not_to include("Fluffy Pancakes")
      end
    end

    context "with category filters" do
      let(:breakfast) { create(:category, name: "Breakfast") }
      let(:dinner) { create(:category, name: "Dinner") }
      let(:lunch) { create(:category, name: "Lunch") }

      before do
        create(:recipe, title: "Morning Eggs", category: breakfast)
        create(:recipe, title: "Evening Steak", category: dinner)
        create(:recipe, title: "Midday Sandwich", category: lunch)
      end

      it "filters by a single category" do
        get search_recipes_path, params: { category_ids: [ breakfast.id ] }

        expect(response.body).to include("Morning Eggs")
        expect(response.body).not_to include("Evening Steak")
      end

      it "filters by multiple categories" do
        get search_recipes_path, params: { category_ids: [ breakfast.id, dinner.id ] }

        expect(response.body).to include("Morning Eggs")
        expect(response.body).to include("Evening Steak")
        expect(response.body).not_to include("Midday Sandwich")
      end

      it "renders a checkbox for every category" do
        get search_recipes_path

        expect(response.body).to include("category_ids_#{breakfast.id}")
        expect(response.body).to include("category_ids_#{dinner.id}")
      end

      it "ignores a non-array category_ids param" do
        get search_recipes_path, params: { query: "pancakes", category_ids: "nonsense" }

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Fluffy Pancakes")
      end
    end

    context "with sort options" do
      let!(:apple) { create(:recipe, title: "Apple Zorblewaffle", created_at: 3.days.ago) }
      let!(:mango) { create(:recipe, title: "Mango Zorblewaffle", created_at: 1.day.ago) }

      it "sorts alphabetically" do
        get search_recipes_path, params: { query: "zorblewaffle", sort: "alphabetical" }

        expect(response.body.index(apple.title)).to be < response.body.index(mango.title)
      end

      it "sorts by newest" do
        get search_recipes_path, params: { query: "zorblewaffle", sort: "newest" }

        expect(response.body.index(mango.title)).to be < response.body.index(apple.title)
      end

      it "ignores an unrecognised sort value" do
        get search_recipes_path, params: { query: "zorblewaffle", sort: "title; something else" }

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Apple Zorblewaffle")
      end

      it "renders the sort dropdown" do
        get search_recipes_path

        expect(response.body).to include("Sort by")
        expect(response.body).to include("Alphabetical")
      end
    end

    context "with no query" do
      it "returns the empty search form" do
        get search_recipes_path, params: { query: "" }

        expect(response).to have_http_status(:ok)
        expect(response.body).not_to include("Fluffy Pancakes")
      end
    end

    context "with no matching results" do
      it "returns empty results" do
        get search_recipes_path, params: { query: "nonexistent" }

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("No results found")
      end
    end

    it "treats SQL metacharacters as literal search text" do
      expect {
        get search_recipes_path, params: { query: "%' OR '1'='1" }
      }.not_to raise_error

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include("Fluffy Pancakes", "Cheese Omelette")
    end
  end
end

# frozen_string_literal: true

require "swagger_helper"

RSpec.describe "Api::V1::Recipes", type: :request do
  let(:api_key) { create(:api_key) }
  let(:Authorization) { "Bearer #{api_key.token}" }

  path "/api/v1/recipes" do
    get "List recipes" do
      tags "Recipes"
      produces "application/json"
      security [ bearer_auth: [] ]
      parameter name: :page, in: :query, type: :integer, required: false, description: "Page number"
      parameter name: :limit, in: :query, type: :integer, required: false, description: "Items per page"

      response "200", "recipes found" do
        schema type: :object,
               properties: {
                 recipes: { type: :array, items: { "$ref" => "#/components/schemas/Recipe" } },
                 pagination: { "$ref" => "#/components/schemas/Pagination" }
               }

        before { create_list(:recipe, 3) }

        run_test!
      end

      response "401", "unauthorized" do
        schema "$ref" => "#/components/schemas/Error"

        let(:Authorization) { "Bearer invalid" }

        run_test!
      end
    end

    post "Create a recipe" do
      tags "Recipes"
      consumes "application/json"
      produces "application/json"
      security [ bearer_auth: [] ]
      parameter name: :recipe, in: :body, schema: {
        type: :object,
        properties: {
          recipe: {
            type: :object,
            properties: {
              title: { type: :string },
              description: { type: :string },
              serves: { type: :integer },
              prep_time: { type: :string },
              category_id: { type: :integer },
              instructions: { type: :string },
              ingredients: {
                type: :array,
                items: {
                  type: :object,
                  properties: {
                    name: { type: :string },
                    quantity: { type: :number },
                    unit: { type: :string }
                  }
                }
              },
              nutrition: { type: :object }
            },
            required: %w[title description serves prep_time category_id instructions ingredients nutrition]
          }
        }
      }

      let(:category) { create(:category) }

      response "201", "recipe created" do
        schema "$ref" => "#/components/schemas/Recipe"

        let(:recipe) do
          {
            recipe: {
              title: "Test Recipe",
              description: "A test recipe",
              serves: 4,
              prep_time: "30 minutes",
              category_id: category.id,
              instructions: "Mix everything together",
              ingredients: [
                { name: "flour", quantity: "2", unit: "cups" }
              ],
              nutrition: {
                calories: "300", protein: "10g", fat: "5g",
                carbs: "40g", fibre: "3g", sugar: "5g", sodium: "200mg"
              }
            }
          }
        end

        run_test!
      end

      response "401", "unauthorized" do
        schema "$ref" => "#/components/schemas/Error"

        let(:Authorization) { "Bearer invalid" }
        let(:recipe) { { recipe: { title: "Test" } } }

        run_test!
      end

      response "422", "invalid request" do
        schema "$ref" => "#/components/schemas/ValidationErrors"

        let(:recipe) { { recipe: { title: "" } } }

        run_test!
      end
    end
  end

  path "/api/v1/recipes/search" do
    get "Search recipes" do
      tags "Recipes"
      produces "application/json"
      security [ bearer_auth: [] ]
      parameter name: :query, in: :query, type: :string, required: true, description: "Search query"
      parameter name: :page, in: :query, type: :integer, required: false

      response "200", "search results" do
        schema type: :object,
               properties: {
                 recipes: { type: :array, items: { "$ref" => "#/components/schemas/Recipe" } },
                 pagination: { "$ref" => "#/components/schemas/Pagination" }
               }

        let(:query) { "chicken" }
        before { create(:recipe, title: "Chicken Curry") }

        run_test!
      end

      response "200", "SQL metacharacters are treated literally" do
        let(:query) { "%' OR '1'='1" }
        before { create(:recipe, title: "Should Not Match") }

        run_test! do |response|
          expect(response.parsed_body.fetch("recipes")).to be_empty
        end
      end

      response "401", "unauthorized" do
        schema "$ref" => "#/components/schemas/Error"

        let(:Authorization) { "Bearer invalid" }
        let(:query) { "chicken" }

        run_test!
      end
    end
  end

  path "/api/v1/recipes/{id}" do
    parameter name: :id, in: :path, type: :integer, required: true

    get "Show a recipe" do
      tags "Recipes"
      produces "application/json"
      security [ bearer_auth: [] ]

      response "200", "recipe found" do
        schema "$ref" => "#/components/schemas/Recipe"

        let(:id) { create(:recipe).id }

        run_test!
      end

      response "404", "recipe not found" do
        schema "$ref" => "#/components/schemas/Error"

        let(:id) { 0 }

        run_test!
      end

      response "401", "unauthorized" do
        schema "$ref" => "#/components/schemas/Error"

        let(:Authorization) { "Bearer invalid" }
        let(:id) { create(:recipe).id }

        run_test!
      end
    end

    put "Update a recipe" do
      tags "Recipes"
      consumes "application/json"
      produces "application/json"
      security [ bearer_auth: [] ]
      parameter name: :recipe, in: :body, schema: {
        type: :object,
        properties: {
          recipe: {
            type: :object,
            properties: {
              title: { type: :string },
              description: { type: :string }
            }
          }
        }
      }

      let(:existing_recipe) { create(:recipe) }
      let(:id) { existing_recipe.id }

      response "200", "recipe updated" do
        schema "$ref" => "#/components/schemas/Recipe"

        let(:recipe) { { recipe: { title: "Updated Title", description: "Updated description" } } }

        run_test!
      end

      response "401", "unauthorized" do
        schema "$ref" => "#/components/schemas/Error"

        let(:Authorization) { "Bearer invalid" }
        let(:recipe) { { recipe: { title: "Updated Title" } } }

        run_test!
      end
    end

    delete "Delete a recipe" do
      tags "Recipes"
      security [ bearer_auth: [] ]

      let(:id) { create(:recipe).id }

      response "204", "recipe deleted" do
        run_test!
      end

      response "401", "unauthorized" do
        schema "$ref" => "#/components/schemas/Error"

        let(:Authorization) { "Bearer invalid" }

        run_test!
      end
    end
  end
end

# frozen_string_literal: true

require "swagger_helper"

RSpec.describe "Api::V1::Baskets", type: :request do
  let(:api_key) { create(:api_key) }
  let(:user) { api_key.user }
  let(:Authorization) { "Bearer #{api_key.token}" }

  path "/api/v1/baskets" do
    get "List basket items" do
      tags "Baskets"
      produces "application/json"
      security [ bearer_auth: [] ]

      response "200", "basket items found" do
        schema type: :object,
               properties: {
                 baskets: {
                   type: :array,
                   items: {
                     type: :object,
                     properties: {
                       id: { type: :integer },
                       recipe: { "$ref" => "#/components/schemas/Recipe" },
                       added_at: { type: :string, format: "date-time" }
                     }
                   }
                 }
               }

        before { create_list(:basket, 2, user: user) }

        run_test!
      end

      response "401", "unauthorized" do
        schema "$ref" => "#/components/schemas/Error"

        let(:Authorization) { "Bearer invalid" }

        run_test!
      end
    end

    post "Add recipe to basket" do
      tags "Baskets"
      consumes "application/json"
      produces "application/json"
      security [ bearer_auth: [] ]
      parameter name: :basket, in: :body, schema: {
        type: :object,
        properties: {
          basket: {
            type: :object,
            properties: {
              recipe_id: { type: :integer }
            },
            required: %w[recipe_id]
          }
        }
      }

      response "201", "recipe added to basket" do
        schema type: :object,
               properties: {
                 message: { type: :string },
                 basket_id: { type: :integer }
               }

        let(:recipe) { create(:recipe) }
        let(:basket) { { basket: { recipe_id: recipe.id } } }

        run_test!
      end

      response "401", "unauthorized" do
        schema "$ref" => "#/components/schemas/Error"

        let(:Authorization) { "Bearer invalid" }
        let(:basket) { { basket: { recipe_id: 1 } } }

        run_test!
      end

      response "422", "invalid request" do
        schema "$ref" => "#/components/schemas/ValidationErrors"

        let(:recipe) { create(:recipe) }
        let(:basket) { { basket: { recipe_id: recipe.id } } }

        before { create(:basket, user: user, recipe: recipe) }

        run_test!
      end
    end
  end

  path "/api/v1/baskets/{id}" do
    parameter name: :id, in: :path, type: :integer, required: true

    delete "Remove recipe from basket" do
      tags "Baskets"
      security [ bearer_auth: [] ]

      response "204", "recipe removed from basket" do
        let(:basket_item) { create(:basket, user: user) }
        let(:id) { basket_item.id }

        run_test!
      end

      response "401", "unauthorized" do
        schema "$ref" => "#/components/schemas/Error"

        let(:Authorization) { "Bearer invalid" }
        let(:id) { 1 }

        run_test!
      end

      response "404", "basket item not found" do
        schema "$ref" => "#/components/schemas/Error"

        let(:id) { 0 }

        run_test!
      end
    end
  end
end

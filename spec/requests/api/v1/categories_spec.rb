# frozen_string_literal: true

require "swagger_helper"

RSpec.describe "Api::V1::Categories", type: :request do
  let(:api_key) { create(:api_key) }
  let(:Authorization) { "Bearer #{api_key.token}" }

  path "/api/v1/categories" do
    get "List categories" do
      tags "Categories"
      produces "application/json"
      security [ bearer_auth: [] ]

      response "200", "categories found" do
        schema type: :object,
               properties: {
                 categories: {
                   type: :array,
                   items: { "$ref" => "#/components/schemas/Category" }
                 }
               }

        before { create_list(:category, 3) }

        run_test!
      end

      response "401", "unauthorized" do
        schema "$ref" => "#/components/schemas/Error"

        let(:Authorization) { "Bearer invalid" }

        run_test!
      end
    end
  end

  path "/api/v1/categories/{id}" do
    parameter name: :id, in: :path, type: :integer, required: true

    get "Show a category with recipes" do
      tags "Categories"
      produces "application/json"
      security [ bearer_auth: [] ]
      parameter name: :page, in: :query, type: :integer, required: false

      response "200", "category found" do
        schema type: :object,
               properties: {
                 id: { type: :integer },
                 name: { type: :string },
                 recipes: { type: :array, items: { "$ref" => "#/components/schemas/Recipe" } },
                 pagination: { "$ref" => "#/components/schemas/Pagination" }
               }

        let(:category) { create(:category) }
        let(:id) { category.id }

        before { create_list(:recipe, 2, category: category) }

        run_test!
      end

      response "404", "category not found" do
        schema "$ref" => "#/components/schemas/Error"

        let(:id) { 0 }

        run_test!
      end

      response "401", "unauthorized" do
        schema "$ref" => "#/components/schemas/Error"

        let(:Authorization) { "Bearer invalid" }
        let(:id) { create(:category).id }

        run_test!
      end
    end
  end
end

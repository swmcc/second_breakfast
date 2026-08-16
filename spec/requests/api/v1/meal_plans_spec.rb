# frozen_string_literal: true

require "swagger_helper"

RSpec.describe "Api::V1::MealPlans", type: :request do
  let(:api_key) { create(:api_key) }
  let(:user) { api_key.user }
  let(:Authorization) { "Bearer #{api_key.token}" }
  let(:monday) { Date.current.beginning_of_week(:monday) }

  path "/api/v1/meal_plans" do
    get "List meal plans" do
      tags "Meal Plans"
      produces "application/json"
      security [ bearer_auth: [] ]
      parameter name: :filter, in: :query, type: :string, required: false,
                description: "Filter by timeframe: active or archived"
      parameter name: :page, in: :query, type: :integer, required: false

      response "200", "meal plans found" do
        schema type: :object,
               properties: {
                 meal_plans: {
                   type: :array,
                   items: {
                     type: :object,
                     properties: {
                       id: { type: :integer },
                       week_start_date: { type: :string, format: "date" },
                       week_end_date: { type: :string, format: "date" },
                       status: { type: :string, enum: %w[draft accepted] },
                       archived: { type: :boolean },
                       editable: { type: :boolean },
                       entry_count: { type: :integer }
                     }
                   }
                 },
                 meta: { "$ref" => "#/components/schemas/Pagination" }
               }

        before do
          create(:meal_plan, user: user)
          create(:meal_plan, :archived, user: user)
        end

        run_test! do |response|
          expect(response.parsed_body["meal_plans"].size).to eq(2)
        end
      end

      response "200", "filtered to archived plans" do
        let(:filter) { "archived" }

        before do
          create(:meal_plan, user: user)
          create(:meal_plan, :archived, user: user)
        end

        run_test! do |response|
          plans = response.parsed_body["meal_plans"]
          expect(plans.size).to eq(1)
          expect(plans.first["archived"]).to be(true)
        end
      end

      response "401", "unauthorized" do
        schema "$ref" => "#/components/schemas/Error"

        let(:Authorization) { "Bearer invalid" }

        run_test!
      end
    end

    post "Create a meal plan" do
      tags "Meal Plans"
      consumes "application/json"
      produces "application/json"
      security [ bearer_auth: [] ]
      parameter name: :meal_plan, in: :body, schema: {
        type: :object,
        properties: {
          meal_plan: {
            type: :object,
            properties: {
              week_start_date: { type: :string, format: "date", description: "Any date in the target week; normalised to Monday. Defaults to the current week." }
            }
          }
        }
      }

      response "201", "meal plan created" do
        let(:meal_plan) { { meal_plan: { week_start_date: (monday + 1.week + 3.days).iso8601 } } }

        run_test! do |response|
          body = response.parsed_body
          expect(body["week_start_date"]).to eq((monday + 1.week).iso8601)
          expect(body["status"]).to eq("draft")
          expect(body["days"].keys).to eq(MealPlanEntry::DAYS)
        end
      end

      response "201", "defaults to the current week" do
        let(:meal_plan) { { meal_plan: {} } }

        run_test! do |response|
          expect(response.parsed_body["week_start_date"]).to eq(monday.iso8601)
        end
      end

      response "409", "week already planned" do
        schema type: :object,
               properties: {
                 error: { type: :string },
                 meal_plan: { type: :object }
               }

        let(:meal_plan) { { meal_plan: { week_start_date: monday.iso8601 } } }

        before { create(:meal_plan, user: user, week_start_date: monday) }

        run_test! do |response|
          expect(response.parsed_body["meal_plan"]["week_start_date"]).to eq(monday.iso8601)
        end
      end

      response "422", "past week rejected" do
        schema "$ref" => "#/components/schemas/ValidationErrors"

        let(:meal_plan) { { meal_plan: { week_start_date: (monday - 1.week).iso8601 } } }

        run_test!
      end

      response "401", "unauthorized" do
        schema "$ref" => "#/components/schemas/Error"

        let(:Authorization) { "Bearer invalid" }
        let(:meal_plan) { { meal_plan: {} } }

        run_test!
      end
    end
  end

  path "/api/v1/meal_plans/{id}" do
    parameter name: :id, in: :path, type: :integer, required: true

    get "Show a meal plan" do
      tags "Meal Plans"
      produces "application/json"
      security [ bearer_auth: [] ]

      response "200", "meal plan found" do
        let(:plan) { create(:meal_plan, user: user) }
        let(:id) { plan.id }

        before { create(:meal_plan_entry, meal_plan: plan, day_of_week: 2) }

        run_test! do |response|
          body = response.parsed_body
          expect(body["days"]["wednesday"].size).to eq(1)
          expect(body["days"]["wednesday"].first["recipe"]).to include("id", "title", "serves")
        end
      end

      response "404", "not found or not owned" do
        schema "$ref" => "#/components/schemas/Error"

        let(:id) { create(:meal_plan).id }

        run_test!
      end
    end

    delete "Delete a meal plan" do
      tags "Meal Plans"
      produces "application/json"
      security [ bearer_auth: [] ]

      response "204", "draft plan deleted" do
        let(:id) { create(:meal_plan, user: user).id }

        run_test!
      end

      response "422", "locked plan cannot be deleted" do
        schema "$ref" => "#/components/schemas/ValidationErrors"

        let(:id) { create(:meal_plan, :accepted, user: user).id }

        run_test!
      end
    end
  end

  path "/api/v1/meal_plans/{id}/accept" do
    parameter name: :id, in: :path, type: :integer, required: true

    post "Accept a meal plan" do
      tags "Meal Plans"
      produces "application/json"
      security [ bearer_auth: [] ]

      response "200", "plan accepted" do
        let(:id) { create(:meal_plan, user: user).id }

        run_test! do |response|
          expect(response.parsed_body["status"]).to eq("accepted")
          expect(response.parsed_body["editable"]).to be(false)
        end
      end

      response "422", "already accepted" do
        schema "$ref" => "#/components/schemas/ValidationErrors"

        let(:id) { create(:meal_plan, :accepted, user: user).id }

        run_test!
      end
    end
  end

  path "/api/v1/meal_plans/{id}/reopen" do
    parameter name: :id, in: :path, type: :integer, required: true

    post "Reopen an accepted meal plan" do
      tags "Meal Plans"
      produces "application/json"
      security [ bearer_auth: [] ]

      response "200", "plan reopened" do
        let(:id) { create(:meal_plan, :accepted, user: user).id }

        run_test! do |response|
          expect(response.parsed_body["status"]).to eq("draft")
        end
      end

      response "422", "draft plans cannot be reopened" do
        schema "$ref" => "#/components/schemas/ValidationErrors"

        let(:id) { create(:meal_plan, user: user).id }

        run_test!
      end
    end
  end

  path "/api/v1/meal_plans/{id}/shopping_list" do
    parameter name: :id, in: :path, type: :integer, required: true

    get "Aggregated shopping list for a meal plan" do
      tags "Meal Plans"
      produces "application/json"
      security [ bearer_auth: [] ]

      response "200", "shopping list" do
        schema type: :object,
               properties: {
                 week_start_date: { type: :string, format: "date" },
                 ingredients: {
                   type: :array,
                   items: {
                     type: :object,
                     properties: {
                       name: { type: :string },
                       quantity: { type: :number },
                       unit: { type: :string, nullable: true }
                     }
                   }
                 }
               }

        let(:plan) { create(:meal_plan, user: user) }
        let(:id) { plan.id }

        before do
          recipe = create(:recipe, ingredients: [ { "name" => "onion", "quantity" => "2", "unit" => "whole" } ])
          create(:meal_plan_entry, meal_plan: plan, recipe: recipe)
        end

        run_test! do |response|
          expect(response.parsed_body["ingredients"]).to contain_exactly(
            a_hash_including("name" => "onion", "quantity" => 2.0)
          )
        end
      end
    end
  end

  path "/api/v1/meal_plans/{meal_plan_id}/entries" do
    parameter name: :meal_plan_id, in: :path, type: :integer, required: true

    post "Add a recipe to a day" do
      tags "Meal Plans"
      consumes "application/json"
      produces "application/json"
      security [ bearer_auth: [] ]
      parameter name: :entry, in: :body, schema: {
        type: :object,
        properties: {
          entry: {
            type: :object,
            properties: {
              recipe_id: { type: :integer },
              day: { type: :string, enum: MealPlanEntry::DAYS }
            },
            required: %w[recipe_id day]
          }
        }
      }

      let(:plan) { create(:meal_plan, user: user) }
      let(:meal_plan_id) { plan.id }
      let(:recipe) { create(:recipe) }

      response "201", "entry added" do
        let(:entry) { { entry: { recipe_id: recipe.id, day: "wednesday" } } }

        run_test! do |response|
          expect(response.parsed_body["day"]).to eq("wednesday")
          expect(response.parsed_body["recipe"]["id"]).to eq(recipe.id)
        end
      end

      response "422", "invalid day name" do
        schema "$ref" => "#/components/schemas/ValidationErrors"

        let(:entry) { { entry: { recipe_id: recipe.id, day: "someday" } } }

        run_test!
      end

      response "422", "locked plan rejects entries" do
        let(:plan) { create(:meal_plan, :accepted, user: user) }
        let(:entry) { { entry: { recipe_id: recipe.id, day: "monday" } } }

        run_test!
      end
    end
  end

  path "/api/v1/meal_plans/{meal_plan_id}/entries/{id}" do
    parameter name: :meal_plan_id, in: :path, type: :integer, required: true
    parameter name: :id, in: :path, type: :integer, required: true

    delete "Remove a recipe from a day" do
      tags "Meal Plans"
      produces "application/json"
      security [ bearer_auth: [] ]

      let(:plan) { create(:meal_plan, user: user) }
      let(:meal_plan_id) { plan.id }

      response "204", "entry removed" do
        let(:id) { create(:meal_plan_entry, meal_plan: plan).id }

        run_test!
      end

      response "422", "locked plan rejects removal" do
        schema "$ref" => "#/components/schemas/ValidationErrors"

        let(:id) do
          entry = create(:meal_plan_entry, meal_plan: plan)
          plan.accept!
          entry.id
        end

        run_test!
      end

      response "404", "entry not found" do
        schema "$ref" => "#/components/schemas/Error"

        let(:id) { 0 }

        run_test!
      end
    end
  end
end

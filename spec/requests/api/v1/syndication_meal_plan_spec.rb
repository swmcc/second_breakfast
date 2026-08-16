# frozen_string_literal: true

require "swagger_helper"

RSpec.describe "Api::V1::Syndication::MealPlans", type: :request do
  let(:monday) { Date.current.beginning_of_week(:monday) }

  path "/api/v1/syndication/meal_plan" do
    get "Current week's meal plan for syndication (public, no auth)" do
      tags "Syndication"
      produces "application/json"
      security []
      description "Public feed of the current week's meal plan for embedding on swm.cc. " \
                  "Returns the plan for the site owner's account; meal_plan is null when nothing is planned."

      response "200", "current week's plan" do
        schema type: :object,
               properties: {
                 week_start_date: { type: :string, format: "date" },
                 week_end_date: { type: :string, format: "date" },
                 meal_plan: {
                   type: :object,
                   nullable: true,
                   properties: {
                     status: { type: :string, enum: %w[draft accepted] },
                     days: {
                       type: :object,
                       properties: MealPlanEntry::DAYS.index_with {
                         {
                           type: :array,
                           items: {
                             type: :object,
                             properties: {
                               title: { type: :string },
                               description: { type: :string, nullable: true },
                               category: { type: :string, nullable: true },
                               serves: { type: :integer, nullable: true },
                               prep_time: { type: :string, nullable: true },
                               url: { type: :string },
                               image_url: { type: :string, nullable: true }
                             }
                           }
                         }
                       }
                     }
                   }
                 }
               }

        before do
          owner = create(:user, email: "me@swm.cc")
          plan = create(:meal_plan, user: owner)
          create(:meal_plan_entry, meal_plan: plan, day_of_week: 0)
        end

        run_test! do |response|
          body = response.parsed_body
          expect(body["week_start_date"]).to eq(monday.iso8601)
          expect(body["meal_plan"]["days"].keys).to eq(MealPlanEntry::DAYS)
          expect(body["meal_plan"]["days"]["monday"].size).to eq(1)
        end
      end

      response "200", "no plan for the current week" do
        before { create(:user, email: "me@swm.cc") }

        run_test! do |response|
          expect(response.parsed_body["meal_plan"]).to be_nil
        end
      end
    end
  end
end

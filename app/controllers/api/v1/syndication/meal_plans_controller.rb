# frozen_string_literal: true

module Api
  module V1
    module Syndication
      # Public, unauthenticated feed of the current week's meal plan for
      # syndication on swm.cc. This is the single deliberate exception to
      # the API-wide key auth: one user's current week, nothing else.
      class MealPlansController < BaseController
        include MealPlansHelper

        skip_before_action :authenticate_api_token!

        SYNDICATION_EMAIL = "me@swm.cc"

        def show
          monday = MealPlan.normalize_week_start(Date.current)
          plan = syndicated_plan(monday)

          expires_in 5.minutes, public: true
          return unless stale?(etag: [ monday.iso8601, plan&.updated_at&.iso8601(6) ])

          render json: {
            week_start_date: monday,
            week_end_date: monday + 6.days,
            meal_plan: plan && plan_json(plan)
          }
        end

        private

        def syndicated_plan(monday)
          user = User.find_by(email: SYNDICATION_EMAIL)
          return nil unless user

          user.meal_plans
              .includes(meal_plan_entries: { recipe: [ :category, { image_attachment: :blob } ] })
              .find_by(week_start_date: monday)
        end

        def plan_json(plan)
          days = MealPlanEntry::DAYS.index_with { [] }
          plan.meal_plan_entries.group_by(&:day_name).each do |day_name, entries|
            days[day_name] = sorted_day_entries(entries).map { |entry| entry_json(entry) }
          end

          { status: plan.status, days: days }
        end

        def entry_json(entry)
          recipe = entry.recipe
          {
            title: recipe.title,
            description: recipe.description,
            category: recipe.category&.name,
            serves: recipe.serves,
            prep_time: recipe.prep_time,
            url: recipe_url(recipe),
            image_url: recipe.image.attached? ? url_for(recipe.image) : nil
          }
        end
      end
    end
  end
end

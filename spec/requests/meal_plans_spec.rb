# frozen_string_literal: true

require "rails_helper"

RSpec.describe "MealPlans", type: :request do
  include ActiveSupport::Testing::TimeHelpers

  let(:user) { create(:user) }
  let(:monday) { Date.current.beginning_of_week(:monday) }

  describe "authentication" do
    it "redirects every action to sign-in when logged out" do
      get meal_plans_path
      expect(response).to redirect_to(sign_in_path)

      post meal_plans_path
      expect(response).to redirect_to(sign_in_path)

      get archive_meal_plans_path
      expect(response).to redirect_to(sign_in_path)
    end
  end

  describe "POST /meal_plans" do
    before { sign_in(user) }

    it "creates a plan for the current week by default" do
      post meal_plans_path

      plan = user.meal_plans.sole
      expect(plan.week_start_date).to eq(monday)
      expect(response).to redirect_to(meal_plan_path(plan))
    end

    it "normalises any date to that week's Monday" do
      post meal_plans_path, params: { meal_plan: { week_start_date: (monday + 1.week + 4.days).iso8601 } }

      expect(user.meal_plans.sole.week_start_date).to eq(monday + 1.week)
    end

    it "redirects to the existing plan when the week is already planned" do
      existing = create(:meal_plan, user: user)

      expect {
        post meal_plans_path, params: { meal_plan: { week_start_date: (monday + 2.days).iso8601 } }
      }.not_to change(MealPlan, :count)

      expect(response).to redirect_to(meal_plan_path(existing))
    end

    it "rejects past weeks" do
      expect {
        post meal_plans_path, params: { meal_plan: { week_start_date: (monday - 1.week).iso8601 } }
      }.not_to change(MealPlan, :count)

      expect(response).to redirect_to(meal_plans_path)
    end
  end

  describe "lifecycle actions" do
    before { sign_in(user) }

    it "accepts and reopens a plan" do
      plan = create(:meal_plan, user: user)

      post accept_meal_plan_path(plan)
      expect(plan.reload).to be_accepted

      post reopen_meal_plan_path(plan)
      expect(plan.reload).to be_draft
    end

    it "blocks destroy on an accepted plan" do
      plan = create(:meal_plan, :accepted, user: user)

      expect { delete meal_plan_path(plan) }.not_to change(MealPlan, :count)
      expect(response).to redirect_to(meal_plan_path(plan))
    end

    it "destroys a draft plan" do
      plan = create(:meal_plan, user: user)

      expect { delete meal_plan_path(plan) }.to change(MealPlan, :count).by(-1)
    end

    it "404s on another user's plan" do
      other = create(:meal_plan)

      get meal_plan_path(other)

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "GET /meal_plans/archive" do
    before { sign_in(user) }

    it "lists only past weeks" do
      create(:meal_plan, user: user)
      old = create(:meal_plan, :archived, user: user)

      get archive_meal_plans_path

      expect(response.body).to include(old.week_start_date.strftime("%-d %b"))
      expect(response.body).not_to include("This week")
    end
  end

  describe "entries" do
    before { sign_in(user) }

    let(:plan) { create(:meal_plan, user: user) }
    let(:recipe) { create(:recipe) }

    it "adds a recipe to a day" do
      post meal_plan_entries_path(plan), params: { entry: { recipe_id: recipe.id, day: "wednesday" } }

      entry = plan.meal_plan_entries.sole
      expect(entry.day_name).to eq("wednesday")
      expect(entry.recipe).to eq(recipe)
    end

    it "removes an entry" do
      entry = create(:meal_plan_entry, meal_plan: plan)

      expect {
        delete meal_plan_entry_path(plan, entry)
      }.to change(MealPlanEntry, :count).by(-1)
    end

    it "rejects mutations on a locked plan" do
      entry = create(:meal_plan_entry, meal_plan: plan)
      plan.accept!

      post meal_plan_entries_path(plan), params: { entry: { recipe_id: recipe.id, day: "monday" } }
      expect(plan.meal_plan_entries.count).to eq(1)

      delete meal_plan_entry_path(plan, entry)
      expect(MealPlanEntry.exists?(entry.id)).to be(true)
    end

    it "rejects an invalid day name" do
      post meal_plan_entries_path(plan), params: { entry: { recipe_id: recipe.id, day: "funday" } }

      expect(plan.meal_plan_entries.count).to eq(0)
      expect(response).to redirect_to(meal_plan_path(plan))
    end

    it "404s on another user's plan" do
      other_plan = create(:meal_plan)

      post meal_plan_entries_path(other_plan), params: { entry: { recipe_id: recipe.id, day: "monday" } }

      expect(response).to have_http_status(:not_found)
    end
  end
end

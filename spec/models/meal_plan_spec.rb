# frozen_string_literal: true

require "rails_helper"

RSpec.describe MealPlan, type: :model do
  include ActiveSupport::Testing::TimeHelpers

  let(:user) { create(:user) }
  let(:monday) { Date.current.beginning_of_week(:monday) }

  describe "week normalisation" do
    it "normalises any date to that week's Monday" do
      plan = create(:meal_plan, user: user, week_start_date: monday + 3.days)

      expect(plan.week_start_date).to eq(monday)
    end

    it "exposes normalize_week_start as a class method" do
      expect(described_class.normalize_week_start(monday + 6.days)).to eq(monday)
    end

    it "computes week_end_date as the following Sunday" do
      plan = create(:meal_plan, user: user)

      expect(plan.week_end_date).to eq(monday + 6.days)
      expect(plan.week_end_date.sunday?).to be(true)
    end
  end

  describe "uniqueness" do
    it "allows only one plan per user per week" do
      create(:meal_plan, user: user)
      duplicate = build(:meal_plan, user: user, week_start_date: monday + 2.days)

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:week_start_date]).to include("already has a plan for this week")
    end

    it "allows different users to plan the same week" do
      create(:meal_plan, user: user)

      expect(build(:meal_plan, week_start_date: monday)).to be_valid
    end
  end

  describe "past week rejection" do
    it "rejects creating a plan for a past week" do
      plan = build(:meal_plan, user: user, week_start_date: 1.week.ago)

      expect(plan).not_to be_valid
      expect(plan.errors[:week_start_date]).to include("cannot be in a past week")
    end

    it "allows future weeks" do
      expect(build(:meal_plan, user: user, week_start_date: 3.weeks.from_now)).to be_valid
    end

    it "supports the :archived factory trait via validate: false" do
      plan = create(:meal_plan, :archived, user: user)

      expect(plan).to be_persisted
      expect(plan.archived?).to be(true)
    end
  end

  describe "lifecycle" do
    it "accepts a draft plan" do
      plan = create(:meal_plan, user: user)

      expect(plan.accept!).to be(true)
      expect(plan.reload).to be_accepted
    end

    it "does not accept an already accepted plan" do
      plan = create(:meal_plan, :accepted, user: user)

      expect(plan.accept!).to be(false)
    end

    it "reopens an accepted plan" do
      plan = create(:meal_plan, :accepted, user: user)

      expect(plan.reopen!).to be(true)
      expect(plan.reload).to be_draft
    end

    it "does not reopen a draft plan" do
      plan = create(:meal_plan, user: user)

      expect(plan.reopen!).to be(false)
    end

    it "refuses accept and reopen on archived plans" do
      plan = create(:meal_plan, user: user)

      travel_to(2.weeks.from_now) do
        expect(plan.accept!).to be(false)
        plan.update_column(:status, "accepted")
        expect(plan.reopen!).to be(false)
      end
    end
  end

  describe "date-derived states" do
    it "derives archived? once the week has fully passed" do
      plan = create(:meal_plan, user: user)

      expect(plan.archived?).to be(false)

      travel_to(plan.week_end_date + 1.day) do
        expect(plan.archived?).to be(true)
        expect(plan.editable?).to be(false)
        expect(plan.locked?).to be(true)
      end
    end

    it "stays current until Sunday ends" do
      plan = create(:meal_plan, user: user)

      travel_to(plan.week_end_date) do
        expect(plan.archived?).to be(false)
        expect(plan.current_week?).to be(true)
      end
    end

    it "scopes archived and active by the current Monday" do
      current = create(:meal_plan, user: user)
      old = create(:meal_plan, :archived, user: user)

      expect(described_class.archived).to contain_exactly(old)
      expect(described_class.active).to contain_exactly(current)
    end

    it "orders newest week first" do
      current = create(:meal_plan, user: user)
      upcoming = create(:meal_plan, user: user, week_start_date: 1.week.from_now)

      expect(described_class.ordered).to eq([ upcoming, current ])
    end
  end

  describe "#aggregated_ingredients" do
    it "counts a recipe once per planned day" do
      recipe = create(:recipe, ingredients: [ { "name" => "onion", "quantity" => "1", "unit" => "whole" } ])
      plan = create(:meal_plan, user: user)
      create(:meal_plan_entry, meal_plan: plan, recipe: recipe, day_of_week: 0)
      create(:meal_plan_entry, meal_plan: plan, recipe: recipe, day_of_week: 1)

      onion = plan.aggregated_ingredients.find { |i| i[:name] == "onion" }
      expect(onion[:quantity]).to eq(2.0)
      expect(onion[:unit]).to eq("whole")
    end
  end
end

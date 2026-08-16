# frozen_string_literal: true

require "rails_helper"

RSpec.describe MealPlanEntry, type: :model do
  let(:plan) { create(:meal_plan) }

  describe "day handling" do
    it "maps day names to indexes with Monday as 0" do
      expect(described_class.day_index("monday")).to eq(0)
      expect(described_class.day_index("Sunday")).to eq(6)
      expect(described_class.day_index("notaday")).to be_nil
    end

    it "exposes day_name" do
      entry = create(:meal_plan_entry, meal_plan: plan, day_of_week: 4)

      expect(entry.day_name).to eq("friday")
    end

    it "rejects out-of-range days" do
      expect(build(:meal_plan_entry, meal_plan: plan, day_of_week: 7)).not_to be_valid
    end
  end

  describe "uniqueness" do
    it "rejects the same recipe twice on the same day" do
      entry = create(:meal_plan_entry, meal_plan: plan)
      duplicate = build(:meal_plan_entry, meal_plan: plan, recipe: entry.recipe, day_of_week: entry.day_of_week)

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:recipe_id]).to include("is already planned for that day")
    end

    it "allows the same recipe on a different day" do
      entry = create(:meal_plan_entry, meal_plan: plan)

      expect(build(:meal_plan_entry, meal_plan: plan, recipe: entry.recipe, day_of_week: 3)).to be_valid
    end
  end

  describe "editability guards" do
    it "rejects creation on an accepted plan" do
      accepted = create(:meal_plan, :accepted)
      entry = build(:meal_plan_entry, meal_plan: accepted)

      expect(entry).not_to be_valid
      expect(entry.errors[:base]).to include("meal plan is not editable")
    end

    it "rejects destroy on a locked plan" do
      entry = create(:meal_plan_entry, meal_plan: plan)
      plan.accept!

      expect(entry.destroy).to be(false)
      expect(entry.errors[:base]).to include("meal plan is not editable")
      expect(described_class.exists?(entry.id)).to be(true)
    end

    it "allows destroy while draft" do
      entry = create(:meal_plan_entry, meal_plan: plan)

      expect { entry.destroy }.to change(described_class, :count).by(-1)
    end
  end
end

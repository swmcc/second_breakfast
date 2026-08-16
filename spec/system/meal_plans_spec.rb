# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Weekly meal plans", type: :system do
  let(:user) { create(:user) }
  let!(:recipe) { create(:recipe, title: "Lentil Soup") }

  before { sign_in_as(user) }

  it "creates this week's plan and manages meals on the board" do
    visit meal_plans_path

    click_button "Plan this week"
    expect(page).to have_content("This week")
    expect(page).to have_content("Draft")

    # Add a recipe to Monday via the picker
    within("#day-monday") { click_button "Add" }
    fill_in placeholder: "Search recipes…", with: "Lentil"
    click_button "Lentil Soup"

    within("#day-monday") { expect(page).to have_link("Lentil Soup") }

    # Shopping list reflects the plan
    expect(page).to have_content("Shopping List")

    # Remove it again
    within("#day-monday") do
      accept_confirm { find("button[title='Remove Lentil Soup']").click }
      expect(page).not_to have_link("Lentil Soup")
    end
  end

  it "accepts a plan, locking the board, then reopens it" do
    plan = create(:meal_plan, user: user)
    create(:meal_plan_entry, meal_plan: plan, recipe: recipe, day_of_week: 0)

    visit meal_plan_path(plan)

    accept_confirm { click_button "Accept plan" }
    expect(page).to have_content("Accepted")
    expect(page).not_to have_button("Add")
    expect(page).not_to have_css("button[title='Remove Lentil Soup']")

    click_button "Reopen"
    expect(page).to have_content("Draft")
    expect(page).to have_button("Add", minimum: 1)
  end

  it "shows archived plans read-only" do
    plan = create(:meal_plan, :archived, user: user)
    MealPlanEntry.insert!({
      meal_plan_id: plan.id, recipe_id: recipe.id, day_of_week: 2,
      created_at: Time.current, updated_at: Time.current
    })

    visit meal_plan_path(plan)

    expect(page).to have_content("This week is archived")
    expect(page).to have_content("Archived")
    expect(page).to have_link("Lentil Soup")
    expect(page).not_to have_button("Add")
    expect(page).not_to have_button("Accept plan")
    expect(page).not_to have_button("Reopen")
  end

  it "prevents planning the same week twice" do
    create(:meal_plan, user: user)

    visit meal_plans_path

    expect(page).not_to have_button("Plan this week")
    expect(page).to have_link("Open this week's plan")
  end
end

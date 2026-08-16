# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Syndication meal plan behaviour", type: :request do
  let(:monday) { Date.current.beginning_of_week(:monday) }
  let(:owner) { create(:user, email: "me@swm.cc") }

  def fetch_feed
    get "/api/v1/syndication/meal_plan", headers: { "Accept" => "application/json" }
  end

  it "requires no Authorization header" do
    create(:meal_plan, user: owner)

    fetch_feed

    expect(response).to have_http_status(:ok)
  end

  it "serves only the syndication user's plan" do
    other_plan = create(:meal_plan, week_start_date: monday)
    create(:meal_plan_entry, meal_plan: other_plan)
    create(:meal_plan, user: owner)

    fetch_feed

    expect(response.parsed_body["meal_plan"]["days"].values.flatten).to be_empty
  end

  it "returns meal_plan null when the syndication user does not exist" do
    fetch_feed

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body["meal_plan"]).to be_nil
  end

  it "returns absolute image URLs and null when no image" do
    plan = create(:meal_plan, user: owner)
    with_image = create(:recipe, title: "Pictured")
    with_image.image.attach(io: StringIO.new("img"), filename: "p.jpg", content_type: "image/jpeg")
    create(:meal_plan_entry, meal_plan: plan, recipe: with_image, day_of_week: 0)
    create(:meal_plan_entry, meal_plan: plan, day_of_week: 1)

    fetch_feed

    monday_entry = response.parsed_body["meal_plan"]["days"]["monday"].first
    tuesday_entry = response.parsed_body["meal_plan"]["days"]["tuesday"].first
    expect(monday_entry["image_url"]).to start_with("http")
    expect(tuesday_entry["image_url"]).to be_nil
  end

  it "orders a day's meals breakfast -> lunch -> dinner" do
    plan = create(:meal_plan, user: owner)
    dinner = create(:recipe, category: create(:category, name: "Dinner"))
    breakfast = create(:recipe, category: create(:category, name: "Breakfast"))
    create(:meal_plan_entry, meal_plan: plan, recipe: dinner, day_of_week: 0)
    create(:meal_plan_entry, meal_plan: plan, recipe: breakfast, day_of_week: 0)

    fetch_feed

    titles = response.parsed_body["meal_plan"]["days"]["monday"].map { |e| e["category"] }
    expect(titles).to eq(%w[Breakfast Dinner])
  end

  it "sets public cache headers and honours ETags" do
    create(:meal_plan, user: owner)

    fetch_feed
    expect(response.headers["Cache-Control"]).to include("public")
    expect(response.headers["Cache-Control"]).to include("max-age=300")
    etag = response.headers["ETag"]
    expect(etag).to be_present

    get "/api/v1/syndication/meal_plan", headers: { "Accept" => "application/json", "If-None-Match" => etag }
    expect(response).to have_http_status(:not_modified)
  end

  it "changes the ETag when an entry is added" do
    plan = create(:meal_plan, user: owner)

    fetch_feed
    etag = response.headers["ETag"]

    create(:meal_plan_entry, meal_plan: plan)

    get "/api/v1/syndication/meal_plan", headers: { "Accept" => "application/json", "If-None-Match" => etag }
    expect(response).to have_http_status(:ok)
  end

  it "does not loosen auth on any other endpoint" do
    get "/api/v1/meal_plans", headers: { "Accept" => "application/json" }
    expect(response).to have_http_status(:unauthorized)

    get "/api/v1/recipes", headers: { "Accept" => "application/json" }
    expect(response).to have_http_status(:unauthorized)
  end
end

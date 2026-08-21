# frozen_string_literal: true

require "rails_helper"

# The basket count in the nav is the one cached fragment on the site that holds
# per-user data. These specs exist to prove it can never be served to the wrong
# person: the fragment key is built from `current_user`, so it carries the user
# id and their updated_at, and Basket touches the user so the count is never
# stale.
RSpec.describe "Cached basket count", :caching, type: :request do
  let(:category) { create(:category) }
  let(:alice) { create(:user, email: "alice@example.com") }
  let(:bob) { create(:user, email: "bob@example.com") }

  before do
    @recipes = create_list(:recipe, 3, category: category)
  end

  it "never shows one user's basket count to another user" do
    @recipes.each { |recipe| create(:basket, user: alice, recipe: recipe) }

    sign_in(alice)
    get recipes_path
    expect(response.body).to include("3 Saved Recipes")

    sign_out

    sign_in(bob)
    get recipes_path
    expect(response.body).to include("0 Saved Recipes")
    expect(response.body).not_to include("3 Saved Recipes")
  end

  it "never shows a signed-in user's basket count to a signed-out visitor" do
    create(:basket, user: alice, recipe: @recipes.first)

    sign_in(alice)
    get recipes_path
    expect(response.body).to include("1 Saved Recipe")

    sign_out

    get recipes_path
    expect(response.body).not_to include("Saved Recipe")
    expect(response.body).not_to include(alice.email)
    expect(response.body).to include("Sign In")
  end

  it "keeps auth-dependent nav chrome out of the cached fragments" do
    # Guest first, so any cached nav fragment is written by a signed-out request.
    get recipes_path
    expect(response.body).to include("Sign In")

    sign_in(alice)
    get recipes_path
    expect(response.body).to include(alice.email)
    expect(response.body).not_to include(">Sign In<")
  end

  it "invalidates the cached count when the user's basket changes" do
    sign_in(alice)

    get recipes_path
    expect(response.body).to include("0 Saved Recipes")

    # Bypasses the belongs_to touch, so the user's cache key does not move and
    # the cached fragment is (correctly) still served - this proves the count
    # really is coming out of the cache.
    Basket.insert!({ user_id: alice.id, recipe_id: @recipes.first.id, created_at: Time.current, updated_at: Time.current })
    get recipes_path
    expect(response.body).to include("0 Saved Recipes")

    # A normal create touches the user, moving their cache key.
    create(:basket, user: alice, recipe: @recipes.second)
    get recipes_path
    expect(response.body).to include("2 Saved Recipes")

    alice.baskets.last.destroy!
    get recipes_path
    expect(response.body).to include("1 Saved Recipe")
  end

  it "does not leak another user's basket state into the recipe cards" do
    create(:basket, user: alice, recipe: @recipes.first)

    sign_in(alice)
    get recipes_path
    expect(response.body).to include("Planned")

    sign_out
    sign_in(bob)
    get recipes_path
    expect(response.body).not_to include("Planned")
  end
end

# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1 authentication", type: :request do
  let(:api_key) { create(:api_key) }
  let(:recipe) { create(:recipe) }
  let(:category) { create(:category) }

  shared_examples "a protected endpoint" do |method, path_proc|
    let(:path) { instance_exec(&path_proc) }
    let(:json_headers) { { "Accept" => "application/json" } }

    it "returns 401 with no Authorization header" do
      public_send(method, path, headers: json_headers)

      expect(response).to have_http_status(:unauthorized)
      expect(response.headers["WWW-Authenticate"]).to eq("Bearer")
      expect(response.parsed_body).to eq("error" => "Unauthorized")
    end

    it "returns 401 with a garbage token" do
      public_send(method, path, headers: json_headers.merge("Authorization" => "Bearer garbage"))

      expect(response).to have_http_status(:unauthorized)
    end

    it "returns 401 with a revoked key" do
      raw = api_key.token
      api_key.revoke!

      public_send(method, path, headers: json_headers.merge("Authorization" => "Bearer #{raw}"))

      expect(response).to have_http_status(:unauthorized)
    end

    it "authenticates with a valid key" do
      public_send(method, path, headers: json_headers.merge("Authorization" => "Bearer #{api_key.token}"))

      expect(response).not_to have_http_status(:unauthorized)
    end
  end

  describe "GET /api/v1/recipes" do
    include_examples "a protected endpoint", :get, -> { "/api/v1/recipes" }
  end

  describe "GET /api/v1/recipes/search" do
    include_examples "a protected endpoint", :get, -> { "/api/v1/recipes/search?query=x" }
  end

  describe "GET /api/v1/recipes/:id" do
    include_examples "a protected endpoint", :get, -> { "/api/v1/recipes/#{recipe.id}" }
  end

  describe "GET /api/v1/categories" do
    include_examples "a protected endpoint", :get, -> { "/api/v1/categories" }
  end

  describe "GET /api/v1/categories/:id" do
    include_examples "a protected endpoint", :get, -> { "/api/v1/categories/#{category.id}" }
  end

  describe "GET /api/v1/baskets" do
    include_examples "a protected endpoint", :get, -> { "/api/v1/baskets" }
  end

  describe "usage tracking" do
    it "stamps the key's last_used_at on a successful request" do
      expect {
        get "/api/v1/recipes", headers: { "Authorization" => "Bearer #{api_key.token}" }
      }.to change { api_key.reload.last_used_at }.from(nil)
    end
  end

  describe "the web UI" do
    it "still uses session auth, untouched by API key auth" do
      get "/recipes"

      expect(response).to have_http_status(:ok)
    end
  end
end

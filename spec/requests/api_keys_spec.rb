# frozen_string_literal: true

require "rails_helper"

RSpec.describe "ApiKeys", type: :request do
  let(:user) { create(:user) }

  describe "POST /api_keys" do
    it "redirects to sign-in when logged out" do
      post api_keys_path, params: { api_key: { name: "MCP server" } }

      expect(response).to redirect_to(sign_in_path)
      expect(ApiKey.count).to eq(0)
    end

    it "creates a key and shows the raw token exactly once" do
      sign_in(user)

      post api_keys_path, params: { api_key: { name: "MCP server" } }

      expect(response).to redirect_to(account_path)
      key = user.api_keys.sole
      expect(key.name).to eq("MCP server")

      follow_redirect!
      expect(response.body).to match(/sb_[0-9a-f]{64}/)

      get account_path
      expect(response.body).not_to match(/sb_[0-9a-f]{64}/)
      expect(response.body).to include(key.prefix)
    end

    it "rejects a blank name" do
      sign_in(user)

      post api_keys_path, params: { api_key: { name: "" } }

      expect(response).to redirect_to(account_path)
      expect(ApiKey.count).to eq(0)
    end
  end

  describe "DELETE /api_keys/:id" do
    let!(:api_key) { create(:api_key, user: user) }

    it "redirects to sign-in when logged out" do
      delete api_key_path(api_key)

      expect(response).to redirect_to(sign_in_path)
      expect(api_key.reload).to be_active
    end

    it "revokes the key without deleting it" do
      sign_in(user)

      delete api_key_path(api_key)

      expect(response).to redirect_to(account_path)
      expect(api_key.reload).not_to be_active
      expect(ApiKey.exists?(api_key.id)).to be(true)
    end

    it "returns 404 for another user's key" do
      other_key = create(:api_key)
      sign_in(user)

      delete api_key_path(other_key)

      expect(response).to have_http_status(:not_found)
      expect(other_key.reload).to be_active
    end
  end

  describe "GET /account/export" do
    it "includes key metadata but never tokens or digests" do
      key = create(:api_key, user: user, name: "Export me")
      sign_in(user)

      get account_export_path

      export = JSON.parse(response.body)
      expect(export["api_keys"]).to contain_exactly(
        a_hash_including("name" => "Export me", "prefix" => key.prefix)
      )
      expect(response.body).not_to include(key.token_digest)
      expect(response.body).not_to match(/sb_[0-9a-f]{64}/)
    end
  end
end

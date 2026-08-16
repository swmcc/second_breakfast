# frozen_string_literal: true

require "rails_helper"

RSpec.describe ApiKey, type: :model do
  describe "token generation" do
    let(:api_key) { create(:api_key) }

    it "exposes an sb_-prefixed raw token on the fresh instance" do
      expect(api_key.token).to match(/\Asb_[0-9a-f]{64}\z/)
    end

    it "persists only the SHA-256 digest, never the raw token" do
      raw = api_key.token

      persisted_values = ApiKey.connection.select_one(
        ApiKey.sanitize_sql([ "SELECT * FROM api_keys WHERE id = ?", api_key.id ])
      ).values

      expect(persisted_values).not_to include(raw)
      expect(api_key.token_digest).to eq(Digest::SHA256.hexdigest(raw))
    end

    it "does not expose the raw token after reload" do
      expect(described_class.find(api_key.id).token).to be_nil
    end

    it "derives the prefix from the first 8 characters of the token" do
      expect(api_key.prefix).to eq(api_key.token.first(8))
      expect(api_key.prefix).to start_with("sb_")
    end

    it "requires a name" do
      expect(build(:api_key, name: nil)).not_to be_valid
    end
  end

  describe ".authenticate" do
    let!(:api_key) { create(:api_key) }

    it "returns the key for a valid raw token" do
      expect(described_class.authenticate(api_key.token)).to eq(api_key)
    end

    it "returns nil for an unknown token" do
      expect(described_class.authenticate("sb_#{SecureRandom.hex(32)}")).to be_nil
    end

    it "returns nil for a revoked key's token" do
      raw = api_key.token
      api_key.revoke!

      expect(described_class.authenticate(raw)).to be_nil
    end

    it "returns nil for nil or blank tokens" do
      expect(described_class.authenticate(nil)).to be_nil
      expect(described_class.authenticate("")).to be_nil
    end
  end

  describe "#revoke! and #active?" do
    let(:api_key) { create(:api_key) }

    it "is active until revoked" do
      expect(api_key).to be_active

      api_key.revoke!

      expect(api_key).not_to be_active
      expect(api_key.revoked_at).to be_present
    end

    it "drops out of the active scope when revoked" do
      api_key.revoke!

      expect(described_class.active).not_to include(api_key)
    end
  end

  describe "#touch_last_used!" do
    let(:api_key) { create(:api_key) }

    it "stamps last_used_at when never used" do
      expect { api_key.touch_last_used! }.to change { api_key.reload.last_used_at }.from(nil)
    end

    it "does not stamp again within the throttle interval" do
      api_key.touch_last_used!

      expect { api_key.touch_last_used! }.not_to change { api_key.reload.last_used_at }
    end

    it "stamps again once the throttle interval has passed" do
      api_key.update_column(:last_used_at, 2.minutes.ago)

      expect { api_key.touch_last_used! }.to change { api_key.reload.last_used_at }
    end
  end
end

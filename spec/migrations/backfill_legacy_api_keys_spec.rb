# frozen_string_literal: true

require "rails_helper"
require Rails.root.glob("db/migrate/*_backfill_legacy_api_keys.rb").sole

RSpec.describe BackfillLegacyApiKeys do
  let(:migration) { described_class.new }

  it "backfills users.api_token values as authenticatable legacy keys" do
    legacy_token = SecureRandom.hex(32)
    user = create(:user)
    user.update_column(:api_token, legacy_token)

    ActiveRecord::Migration.suppress_messages { migration.up }

    key = ApiKey.authenticate(legacy_token)
    expect(key).to be_present
    expect(key.user).to eq(user)
    expect(key.name).to eq("Legacy key")
    expect(key.prefix).to eq(legacy_token[0, 8])
  end

  it "skips users without a legacy token" do
    create(:user)

    expect {
      ActiveRecord::Migration.suppress_messages { migration.up }
    }.not_to change(ApiKey, :count)
  end
end

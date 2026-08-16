# frozen_string_literal: true

require "rails_helper"

RSpec.describe "API key management", type: :system do
  let(:user) { create(:user) }

  before { sign_in_as(user) }

  it "creates a key, shows the token once, and hides it after reload" do
    visit account_path

    fill_in "Key name", with: "MCP server"
    click_button "Create key"

    expect(page).to have_content("Copy it now")
    expect(page).to have_content(/sb_[0-9a-f]{64}/)
    expect(page).to have_button("Copy")

    visit account_path

    expect(page).not_to have_content(/sb_[0-9a-f]{64}/)
    expect(page).to have_content("MCP server")
    expect(page).to have_content(user.api_keys.sole.prefix)
    expect(page).to have_content("Last used Never")
  end

  it "revokes a key with confirmation and shows it struck-through" do
    create(:api_key, user: user, name: "Old key")

    visit account_path

    accept_confirm do
      click_link "Revoke"
    end

    expect(page).to have_content("Revoked")
    expect(page).not_to have_link("Revoke")
    expect(user.api_keys.sole).not_to be_active
  end

  it "never renders tokens for pre-existing keys" do
    key = create(:api_key, user: user, name: "Existing")

    visit account_path

    expect(page).to have_content(key.prefix)
    expect(page).not_to have_content(/sb_[0-9a-f]{64}/)
  end
end

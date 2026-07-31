# frozen_string_literal: true

module SystemHelpers
  def sign_in_as(user)
    visit sign_in_path
    fill_in "Email", with: user.email
    fill_in "Password", with: "password123"
    click_button "Sign in"
  end

  def sign_out
    click_link "Sign Out"
  end
end

RSpec.configure do |config|
  config.include SystemHelpers, type: :system
end

require "rails_helper"

RSpec.describe "Password resets", type: :system do
  include ActiveSupport::Testing::TimeHelpers

  let!(:user) { create(:user, email: "test@example.com", password: "password123") }

  before do
    ActionMailer::Base.deliveries.clear
    # Deliver inline so the emailed link is available to follow straight away.
    ActiveJob::Base.queue_adapter.perform_enqueued_jobs = true
  end

  after do
    ActiveJob::Base.queue_adapter.perform_enqueued_jobs = false
  end

  it "walks the whole flow from the sign in page to a new working password" do
    visit sign_in_path
    click_link "Forgot your password?"

    expect(page).to have_current_path(new_password_reset_path)

    fill_in "Email address", with: user.email
    click_button "Send reset instructions"

    expect(page).to have_current_path(sign_in_path)
    expect(page).to have_content("If that email address has an account")

    email = ActionMailer::Base.deliveries.last
    expect(email.to).to eq([ user.email ])

    token = email.body.encoded[%r{/password_resets/([^/\s"<]+)/edit}, 1]
    visit edit_password_reset_path(token: token)

    fill_in "New password", with: "brandnewpassword"
    fill_in "Confirm new password", with: "brandnewpassword"
    click_button "Save new password"

    expect(page).to have_current_path(sign_in_path)
    expect(page).to have_content("Your password has been reset")

    fill_in "Email address", with: user.email
    fill_in "Password", with: "brandnewpassword"
    click_button "Sign in"

    expect(page).to have_current_path(root_path)
    expect(page).to have_content(user.email)
  end

  it "does not reveal whether an address is registered" do
    visit new_password_reset_path
    fill_in "Email address", with: "nobody@example.com"
    click_button "Send reset instructions"

    expect(page).to have_content("If that email address has an account")
    expect(ActionMailer::Base.deliveries).to be_empty
  end

  it "refuses an expired link" do
    token = user.generate_token_for(:password_reset)

    travel_to(User::PASSWORD_RESET_TOKEN_EXPIRY.from_now + 1.minute) do
      visit edit_password_reset_path(token: token)

      expect(page).to have_current_path(new_password_reset_path)
      expect(page).to have_content("invalid or has expired")
    end
  end
end

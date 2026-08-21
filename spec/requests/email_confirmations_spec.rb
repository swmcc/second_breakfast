require "rails_helper"

RSpec.describe "Email confirmations" do
  include ActiveJob::TestHelper
  include ActiveSupport::Testing::TimeHelpers

  let(:user) { create(:user, :unconfirmed, email: "test@example.com", password: "password123") }

  before { ActionMailer::Base.deliveries.clear }

  def last_email
    ActionMailer::Base.deliveries.last
  end

  describe "POST /users (sign up)" do
    subject(:sign_up) do
      perform_enqueued_jobs do
        post users_path, params: {
          user: {
            email: "new@example.com",
            password: "password123",
            password_confirmation: "password123"
          }
        }
      end
    end

    it "creates an unconfirmed account" do
      expect { sign_up }.to change(User, :count).by(1)
      expect(User.find_by(email: "new@example.com")).not_to be_confirmed
    end

    it "sends a confirmation email with an absolute URL" do
      sign_up

      expect(last_email.to).to eq([ "new@example.com" ])
      expect(last_email.subject).to eq("Confirm your Second Breakfast email address")
      expect(last_email.body.encoded).to include("http://example.com/email_confirmation/")
    end

    it "signs the new user in even though they are unconfirmed" do
      sign_up

      expect(response).to redirect_to(root_path)
      get new_recipe_path
      expect(response).to have_http_status(:ok)
    end

    it "re-renders the form when the account is invalid" do
      post users_path, params: { user: { email: "", password: "short", password_confirmation: "nope" } }

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "GET /email_confirmation/:token" do
    it "confirms the account" do
      get email_confirmation_path(token: user.generate_token_for(:email_confirmation))

      expect(user.reload).to be_confirmed
      expect(response).to redirect_to(sign_in_path)
      expect(flash[:notice]).to eq("Thanks — your email address is confirmed.")
    end

    it "sends a signed-in user back to their account page" do
      sign_in(user)

      get email_confirmation_path(token: user.generate_token_for(:email_confirmation))

      expect(response).to redirect_to(account_path)
      expect(user.reload).to be_confirmed
    end

    it "rejects a token that was never issued" do
      get email_confirmation_path(token: "not-a-real-token")

      expect(response).to redirect_to(sign_in_path)
      expect(flash[:alert]).to eq(EmailConfirmationsController::INVALID_TOKEN_ALERT)
      expect(user.reload).not_to be_confirmed
    end

    it "rejects a token belonging to another account" do
      other = create(:user, :unconfirmed)

      get email_confirmation_path(token: other.generate_token_for(:email_confirmation))

      expect(other.reload).to be_confirmed
      expect(user.reload).not_to be_confirmed
    end

    it "rejects an expired token" do
      token = user.generate_token_for(:email_confirmation)

      travel_to(User::EMAIL_CONFIRMATION_TOKEN_EXPIRY.from_now + 1.hour) do
        get email_confirmation_path(token: token)

        expect(response).to redirect_to(sign_in_path)
        expect(flash[:alert]).to eq(EmailConfirmationsController::INVALID_TOKEN_ALERT)
      end

      expect(user.reload).not_to be_confirmed
    end

    it "cannot be replayed once used" do
      token = user.generate_token_for(:email_confirmation)
      get email_confirmation_path(token: token)
      expect(user.reload).to be_confirmed

      get email_confirmation_path(token: token)

      expect(response).to redirect_to(sign_in_path)
      expect(flash[:alert]).to eq(EmailConfirmationsController::INVALID_TOKEN_ALERT)
    end

    it "is void once the address it was sent to has changed" do
      token = user.generate_token_for(:email_confirmation)
      user.update_columns(email: "moved@example.com")

      get email_confirmation_path(token: token)

      expect(response).to redirect_to(sign_in_path)
      expect(user.reload).not_to be_confirmed
    end
  end

  describe "POST /email_confirmation/resend" do
    it "requires a signed-in user, so no address can be probed" do
      post resend_email_confirmation_path

      expect(response).to redirect_to(sign_in_path)
      expect(ActionMailer::Base.deliveries).to be_empty
    end

    it "re-sends the confirmation email to the signed-in user" do
      sign_in(user)

      perform_enqueued_jobs { post resend_email_confirmation_path }

      expect(last_email.to).to eq([ user.email ])
      expect(response).to redirect_to(account_path)
      expect(flash[:notice]).to eq("Confirmation email sent. Please check your inbox.")
    end

    it "does nothing for an already confirmed user" do
      confirmed = create(:user, password: "password123")
      sign_in(confirmed)

      perform_enqueued_jobs { post resend_email_confirmation_path }

      expect(ActionMailer::Base.deliveries).to be_empty
      expect(flash[:notice]).to eq("Your email address is already confirmed.")
    end
  end

  describe "unconfirmed users" do
    it "can still sign in and use the app" do
      sign_in(user)

      get new_recipe_path

      expect(response).to have_http_status(:ok)
    end

    it "are prompted to confirm on the account page" do
      sign_in(user)

      get account_path

      expect(response.body).to include("Confirm your email address")
    end
  end
end

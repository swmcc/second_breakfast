require "rails_helper"

RSpec.describe "Password resets" do
  include ActiveJob::TestHelper
  include ActiveSupport::Testing::TimeHelpers

  subject(:generic_notice) { PasswordResetsController::CONFIRMATION_NOTICE }

  let!(:user) { create(:user, email: "test@example.com", password: "password123") }

  before { ActionMailer::Base.deliveries.clear }

  def request_reset(email)
    perform_enqueued_jobs { post password_resets_path, params: { email: email } }
  end

  def last_email
    ActionMailer::Base.deliveries.last
  end

  def token_from_last_email
    last_email.body.encoded[%r{/password_resets/([^/\s"<]+)/edit}, 1]
  end

  describe "GET /password_resets/new" do
    it "renders the request form" do
      get new_password_reset_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Reset your password")
    end

    it "is also reachable at /forgot_password" do
      get forgot_password_path

      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /password_resets" do
    it "emails a reset link to a registered address" do
      request_reset(user.email)

      expect(ActionMailer::Base.deliveries.size).to eq(1)
      expect(last_email.to).to eq([ user.email ])
      expect(last_email.subject).to eq("Reset your Second Breakfast password")
    end

    it "links to an absolute URL, not a path" do
      request_reset(user.email)

      expect(last_email.body.encoded).to include("http://example.com/password_resets/")
    end

    it "redirects with the generic confirmation" do
      request_reset(user.email)

      expect(response).to redirect_to(sign_in_path)
      expect(flash[:notice]).to eq(generic_notice)
    end

    context "with an address that has no account" do
      it "sends nothing" do
        request_reset("nobody@example.com")

        expect(ActionMailer::Base.deliveries).to be_empty
      end

      it "answers identically, so accounts cannot be enumerated" do
        request_reset("nobody@example.com")
        unknown_response = [ response.status, response.location, flash[:notice] ]

        request_reset(user.email)
        known_response = [ response.status, response.location, flash[:notice] ]

        expect(unknown_response).to eq(known_response)
      end
    end

    describe "rate limiting" do
      # The test env uses :null_store, whose #increment always returns nil, so the
      # rate limiter never trips. Swap in a real counter for these examples.
      let(:rate_limit_store) { ActiveSupport::Cache::MemoryStore.new }

      before do
        allow(ActionController::Base.cache_store).to receive(:increment) do |key, amount = 1, **options|
          rate_limit_store.increment(key, amount, **options)
        end
      end

      it "blocks further requests once the limit is exceeded" do
        5.times { post password_resets_path, params: { email: user.email } }

        post password_resets_path, params: { email: user.email }

        expect(response).to redirect_to(new_password_reset_path)
        expect(flash[:alert]).to eq("Too many password reset requests. Please try again later.")
      end

      it "does not send a sixth email" do
        6.times { perform_enqueued_jobs { post password_resets_path, params: { email: user.email } } }

        expect(ActionMailer::Base.deliveries.size).to eq(5)
      end
    end
  end

  describe "GET /password_resets/:token/edit" do
    it "renders the new-password form for a valid token" do
      get edit_password_reset_path(token: user.generate_token_for(:password_reset))

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Choose a new password")
    end

    it "rejects a token that was never issued" do
      get edit_password_reset_path(token: "not-a-real-token")

      expect(response).to redirect_to(new_password_reset_path)
      expect(flash[:alert]).to eq(PasswordResetsController::INVALID_TOKEN_ALERT)
    end

    it "rejects a token belonging to a deleted account" do
      token = user.generate_token_for(:password_reset)
      user.destroy!

      get edit_password_reset_path(token: token)

      expect(response).to redirect_to(new_password_reset_path)
    end

    it "rejects an expired token" do
      token = user.generate_token_for(:password_reset)

      travel_to(User::PASSWORD_RESET_TOKEN_EXPIRY.from_now + 1.minute) do
        get edit_password_reset_path(token: token)

        expect(response).to redirect_to(new_password_reset_path)
        expect(flash[:alert]).to eq(PasswordResetsController::INVALID_TOKEN_ALERT)
      end
    end
  end

  describe "PATCH /password_resets/:token" do
    let(:token) { user.generate_token_for(:password_reset) }

    def submit_new_password(password:, confirmation: password, with: token)
      patch password_reset_path(token: with),
            params: { password: password, password_confirmation: confirmation }
    end

    it "changes the password" do
      submit_new_password(password: "brandnewpassword")

      expect(user.reload.authenticate("brandnewpassword")).to be_truthy
      expect(user.authenticate("password123")).to be_falsey
    end

    it "redirects to sign in" do
      submit_new_password(password: "brandnewpassword")

      expect(response).to redirect_to(sign_in_path)
      expect(flash[:notice]).to eq("Your password has been reset. Please sign in.")
    end

    it "does not sign the user in" do
      submit_new_password(password: "brandnewpassword")

      expect(session[:user_id]).to be_nil
    end

    it "lets the new password be used to sign in" do
      submit_new_password(password: "brandnewpassword")

      post session_path, params: { email: user.email, password: "brandnewpassword" }

      expect(response).to redirect_to(root_path)
    end

    it "invalidates the token after use" do
      submit_new_password(password: "brandnewpassword")

      submit_new_password(password: "yetanotherpassword")

      expect(response).to redirect_to(new_password_reset_path)
      expect(user.reload.authenticate("brandnewpassword")).to be_truthy
    end

    it "rejects an expired token" do
      expired = token

      travel_to(User::PASSWORD_RESET_TOKEN_EXPIRY.from_now + 1.minute) do
        submit_new_password(password: "brandnewpassword", with: expired)
      end

      expect(response).to redirect_to(new_password_reset_path)
      expect(user.reload.authenticate("password123")).to be_truthy
    end

    it "rejects a mismatched confirmation" do
      submit_new_password(password: "brandnewpassword", confirmation: "somethingelse")

      expect(response).to have_http_status(:unprocessable_entity)
      expect(user.reload.authenticate("password123")).to be_truthy
    end

    it "rejects a blank password" do
      submit_new_password(password: "")

      expect(response).to have_http_status(:unprocessable_entity)
      expect(flash[:alert]).to eq("Password can't be blank")
      expect(user.reload.authenticate("password123")).to be_truthy
    end

    it "rejects a password below the minimum length" do
      submit_new_password(password: "short")

      expect(response).to have_http_status(:unprocessable_entity)
      expect(user.reload.authenticate("password123")).to be_truthy
    end

    it "clears any lockout on the account" do
      user.update_columns(failed_attempts: 3, locked_until: 10.minutes.from_now)
      reset_token = user.reload.generate_token_for(:password_reset)

      submit_new_password(password: "brandnewpassword", with: reset_token)

      expect(user.reload.locked_until).to be_nil
      expect(user.failed_attempts).to be_zero
    end

    it "revokes any remember-me token" do
      user.remember_me!
      reset_token = user.reload.generate_token_for(:password_reset)

      submit_new_password(password: "brandnewpassword", with: reset_token)

      expect(user.reload.remember_token).to be_nil
    end
  end

  describe "end to end" do
    it "walks from the request form to a working new password" do
      request_reset(user.email)

      patch password_reset_path(token: token_from_last_email),
            params: { password: "brandnewpassword", password_confirmation: "brandnewpassword" }

      post session_path, params: { email: user.email, password: "brandnewpassword" }

      expect(response).to redirect_to(root_path)
    end
  end

  describe "logging" do
    it "filters reset tokens and passwords out of the logs" do
      filter = ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters)

      filtered = filter.filter("token" => "a-reset-token", "password" => "password123")

      expect(filtered).to eq("token" => "[FILTERED]", "password" => "[FILTERED]")
    end
  end
end

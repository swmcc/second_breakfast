require "rails_helper"

RSpec.describe "Sessions" do
  let(:user) { create(:user, email: "test@example.com", password: "password123") }

  describe "GET /sign_in" do
    it "renders the login page" do
      get sign_in_path

      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /session" do
    context "with valid credentials" do
      it "logs in the user and redirects to root" do
        post session_path, params: { email: user.email, password: "password123" }

        expect(response).to redirect_to(root_path)
        expect(flash[:notice]).to eq("Logged in successfully")
      end

      it "sets the user session" do
        post session_path, params: { email: user.email, password: "password123" }

        # Verify session is set by accessing a protected resource
        get new_recipe_path
        expect(response).to have_http_status(:ok)
      end
    end

    context "with invalid email" do
      it "does not log in and renders login form with error" do
        post session_path, params: { email: "wrong@example.com", password: "password123" }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(flash[:alert]).to eq("Invalid email or password")
      end
    end

    context "with invalid password" do
      it "does not log in and renders login form with error" do
        post session_path, params: { email: user.email, password: "wrongpassword" }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(flash[:alert]).to eq("Invalid email or password")
      end
    end

    context "with blank credentials" do
      it "does not log in and shows error" do
        post session_path, params: { email: "", password: "" }

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    describe "session fixation" do
      it "issues a new session id when logging in" do
        # Touching a protected page as a guest establishes a session (flash alert).
        get new_recipe_path
        session_id_before = session.id.to_s
        cookie_before = cookies["_second_breakfast_session"]

        post session_path, params: { email: user.email, password: "password123" }

        expect(session[:user_id]).to eq(user.id)
        expect(session.id.to_s).not_to eq(session_id_before)
        expect(cookies["_second_breakfast_session"]).not_to eq(cookie_before)
      end
    end

    describe "rate limiting" do
      include ActiveSupport::Testing::TimeHelpers

      # The test env uses :null_store, whose #increment always returns nil, so the
      # rate limiter never trips. The limiter captures ActionController::Base.cache_store
      # at class-load time, so swap that object's counter for a real one here.
      let(:rate_limit_store) { ActiveSupport::Cache::MemoryStore.new }

      before do
        allow(ActionController::Base.cache_store).to receive(:increment) do |key, amount = 1, **options|
          rate_limit_store.increment(key, amount, **options)
        end
      end

      it "blocks further attempts once the limit is exceeded" do
        10.times do
          post session_path, params: { email: user.email, password: "wrongpassword" }
          expect(response).to have_http_status(:unprocessable_entity)
        end

        post session_path, params: { email: user.email, password: "wrongpassword" }

        expect(response).to redirect_to(sign_in_path)
        expect(flash[:alert]).to eq("Too many login attempts. Please try again later.")
      end

      it "blocks valid credentials too once the limit is exceeded" do
        10.times { post session_path, params: { email: user.email, password: "wrongpassword" } }

        post session_path, params: { email: user.email, password: "password123" }

        expect(response).to redirect_to(sign_in_path)
        expect(flash[:alert]).to eq("Too many login attempts. Please try again later.")
      end

      it "allows attempts again once the window has passed" do
        # Burn the allowance against an address that has no account, so the
        # lockout in `describe "account lockout"` below does not also apply.
        11.times { post session_path, params: { email: "nobody@example.com", password: "wrongpassword" } }

        travel_to 4.minutes.from_now do
          post session_path, params: { email: user.email, password: "password123" }

          expect(response).to redirect_to(root_path)
        end
      end
    end
  end

  describe "account lockout" do
    include ActiveSupport::Testing::TimeHelpers

    def fail_login(times = 1)
      times.times { post session_path, params: { email: user.email, password: "wrongpassword" } }
    end

    it "counts failed attempts without locking below the threshold" do
      fail_login(User::MAX_FAILED_LOGIN_ATTEMPTS - 1)

      expect(user.reload.failed_attempts).to eq(User::MAX_FAILED_LOGIN_ATTEMPTS - 1)
      expect(user).not_to be_locked
    end

    it "locks the account once the threshold is reached" do
      fail_login(User::MAX_FAILED_LOGIN_ATTEMPTS)

      expect(user.reload).to be_locked
    end

    it "refuses the correct password while locked" do
      fail_login(User::MAX_FAILED_LOGIN_ATTEMPTS)

      post session_path, params: { email: user.email, password: "password123" }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(session[:user_id]).to be_nil
    end

    it "does not reveal that the account is locked" do
      fail_login(User::MAX_FAILED_LOGIN_ATTEMPTS)

      post session_path, params: { email: user.email, password: "password123" }

      expect(flash[:alert]).to eq("Invalid email or password")
    end

    it "does not extend the lock while it is in force" do
      fail_login(User::MAX_FAILED_LOGIN_ATTEMPTS)
      locked_until = user.reload.locked_until

      fail_login(2)

      expect(user.reload.locked_until).to eq(locked_until)
    end

    it "unlocks itself once the cooldown has passed" do
      fail_login(User::MAX_FAILED_LOGIN_ATTEMPTS)

      travel_to(User::LOCKOUT_PERIOD.from_now + 1.minute) do
        post session_path, params: { email: user.email, password: "password123" }

        expect(response).to redirect_to(root_path)
      end
    end

    it "clears the counter after a successful sign in" do
      fail_login(2)

      post session_path, params: { email: user.email, password: "password123" }

      expect(user.reload.failed_attempts).to be_zero
      expect(user.reload.locked_until).to be_nil
    end
  end

  describe "remember me" do
    it "does not set a remember cookie when the box is unticked" do
      post session_path, params: { email: user.email, password: "password123" }

      expect(cookies[:remember_me]).to be_blank
      expect(user.reload.remember_token).to be_nil
    end

    it "sets a signed remember cookie and a stored token when ticked" do
      post session_path, params: { email: user.email, password: "password123", remember_me: "1" }

      expect(cookies[:remember_me]).to be_present
      expect(user.reload.remember_token).to be_present
      # The raw user id must never be the whole cookie value.
      expect(cookies[:remember_me]).not_to eq(user.id.to_s)
    end

    it "signs the user back in from the cookie once the session is gone" do
      post session_path, params: { email: user.email, password: "password123", remember_me: "1" }
      remember_cookie = cookies[:remember_me]

      reset!
      cookies[:remember_me] = remember_cookie
      get new_recipe_path

      expect(response).to have_http_status(:ok)
    end

    it "rejects a tampered cookie" do
      post session_path, params: { email: user.email, password: "password123", remember_me: "1" }

      reset!
      cookies[:remember_me] = "#{user.id}:not-the-real-token"
      get new_recipe_path

      expect(response).to redirect_to(sign_in_path)
    end

    it "stops working once the password changes" do
      post session_path, params: { email: user.email, password: "password123", remember_me: "1" }
      remember_cookie = cookies[:remember_me]

      user.update!(password: "brandnewpassword", password_confirmation: "brandnewpassword")

      reset!
      cookies[:remember_me] = remember_cookie
      get new_recipe_path

      expect(response).to redirect_to(sign_in_path)
    end

    it "clears the cookie and the stored token on sign out" do
      post session_path, params: { email: user.email, password: "password123", remember_me: "1" }

      delete sign_out_path

      expect(cookies[:remember_me]).to be_blank
      expect(user.reload.remember_token).to be_nil
    end
  end

  describe "DELETE /sign_out" do
    before { sign_in(user) }

    it "logs out the user and redirects to root" do
      delete sign_out_path

      expect(response).to redirect_to(root_path)
      expect(flash[:notice]).to eq("Logged out successfully")
    end

    it "clears the session so protected resources require login again" do
      delete sign_out_path
      follow_redirect!

      # Protected resource should now redirect to login
      get new_recipe_path
      expect(response).to redirect_to(sign_in_path)
    end
  end
end

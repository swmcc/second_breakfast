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
        11.times { post session_path, params: { email: user.email, password: "wrongpassword" } }

        travel_to 4.minutes.from_now do
          post session_path, params: { email: user.email, password: "password123" }

          expect(response).to redirect_to(root_path)
        end
      end
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

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

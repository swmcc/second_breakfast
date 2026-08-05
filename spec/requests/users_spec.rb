require "rails_helper"

RSpec.describe "Users" do
  describe "GET /account/export" do
    it "requires authentication" do
      get account_export_path

      expect(response).to redirect_to(sign_in_path)
    end

    it "downloads the signed-in user's account data as JSON" do
      user = create(:user)
      baskets = create_list(:basket, 2, user: user)
      sign_in(user)

      get account_export_path

      data = response.parsed_body
      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("application/json")
      expect(response.headers["Content-Disposition"]).to include("attachment")
      expect(data).to include("email" => user.email, "created_at" => user.created_at.as_json)
      expect(data["basket_recipes"]).to match_array(
        baskets.map { |basket| { "id" => basket.recipe.id, "title" => basket.recipe.title } }
      )
    end
  end

  describe "DELETE /account" do
    it "destroys the user and baskets, then clears the session" do
      user = create(:user)
      create_list(:basket, 2, user: user)
      sign_in(user)

      expect do
        delete account_path
      end.to change(User, :count).by(-1).and change(Basket, :count).by(-2)

      expect(response).to redirect_to(root_path)
      expect(flash[:notice]).to eq("Your account has been deleted")

      get account_export_path
      expect(response).to redirect_to(sign_in_path)
    end
  end
end

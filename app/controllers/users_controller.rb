class UsersController < ApplicationController
  before_action :authenticate_user!, only: [ :show, :export, :destroy ]

  def new
    @user = User.new
  end

  def show
    @api_keys = current_user.api_keys.order(created_at: :desc)
  end

  def export
    account_data = {
      email: current_user.email,
      created_at: current_user.created_at,
      basket_recipes: current_user.baskets.includes(:recipe).map do |basket|
        { id: basket.recipe.id, title: basket.recipe.title }
      end,
      api_keys: current_user.api_keys.map do |key|
        {
          name: key.name,
          prefix: key.prefix,
          created_at: key.created_at,
          last_used_at: key.last_used_at,
          revoked_at: key.revoked_at
        }
      end
    }

    send_data JSON.pretty_generate(account_data.as_json),
              filename: "second-breakfast-account-data.json",
              type: "application/json",
              disposition: "attachment"
  end

  def destroy
    current_user.destroy!
    reset_session
    redirect_to root_path, notice: "Your account has been deleted"
  end

  private

  def user_params
    params.require(:user).permit(:email, :password, :password_confirmation)
  end
end

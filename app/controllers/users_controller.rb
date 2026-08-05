class UsersController < ApplicationController
  before_action :authenticate_user!, only: [ :export, :destroy ]

  def new
    @user = User.new
  end

  def show
  end

  def export
    account_data = {
      email: current_user.email,
      created_at: current_user.created_at,
      basket_recipes: current_user.baskets.includes(:recipe).map do |basket|
        { id: basket.recipe.id, title: basket.recipe.title }
      end
    }

    send_data JSON.pretty_generate(account_data),
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

class UsersController < ApplicationController
  before_action :authenticate_user!, only: [ :show, :export, :destroy ]

  def new
    @user = User.new
  end

  # New accounts start unconfirmed. They are signed in straight away and nothing
  # is gated on confirmation yet — see the note in the account page — so turning
  # this on cannot lock anybody out.
  def create
    @user = User.new(user_params)

    if @user.save
      ConfirmationsMailer.confirm(@user).deliver_later
      reset_session
      session[:user_id] = @user.id
      redirect_to root_path, notice: "Welcome to Second Breakfast! Check your email to confirm your address."
    else
      render :new, status: :unprocessable_entity
    end
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

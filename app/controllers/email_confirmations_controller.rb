class EmailConfirmationsController < ApplicationController
  INVALID_TOKEN_ALERT =
    "That confirmation link is invalid or has expired. Sign in and request a new one.".freeze

  # Resending is only offered to the signed-in owner of the account, so there is
  # no address to enumerate here.
  before_action :authenticate_user!, only: :create

  rate_limit to: 5, within: 15.minutes, only: :create,
             with: -> { redirect_to account_path, alert: "Too many confirmation emails requested. Please try again later." }

  def show
    user = User.find_by_token_for(:email_confirmation, params[:token])

    if user
      user.confirm!
      redirect_to after_confirmation_path, notice: "Thanks — your email address is confirmed."
    else
      redirect_to after_confirmation_path, alert: INVALID_TOKEN_ALERT
    end
  end

  def create
    if current_user.confirmed?
      redirect_to account_path, notice: "Your email address is already confirmed."
    else
      ConfirmationsMailer.confirm(current_user).deliver_later
      redirect_to account_path, notice: "Confirmation email sent. Please check your inbox."
    end
  end

  private

  def after_confirmation_path
    user_signed_in? ? account_path : sign_in_path
  end
end

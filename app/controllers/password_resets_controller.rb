class PasswordResetsController < ApplicationController
  # The same answer is given whether or not the address is registered, so this
  # endpoint cannot be used to enumerate accounts.
  CONFIRMATION_NOTICE =
    "If that email address has an account, we've sent password reset instructions to it.".freeze
  INVALID_TOKEN_ALERT =
    "That password reset link is invalid or has expired. Please request a new one.".freeze

  rate_limit to: 5, within: 15.minutes, only: :create,
             with: -> { redirect_to new_password_reset_path, alert: "Too many password reset requests. Please try again later." }

  before_action :set_user_from_token, only: [ :edit, :update ]

  def new
  end

  def create
    user = User.find_by(email: params[:email].to_s)
    PasswordsMailer.reset(user).deliver_later if user

    redirect_to sign_in_path, notice: CONFIRMATION_NOTICE
  end

  def edit
  end

  def update
    if params[:password].blank?
      return render_invalid("Password can't be blank")
    end

    if @user.update(password: params[:password], password_confirmation: params[:password_confirmation])
      # A successful reset also clears any lockout and, via the model callback,
      # revokes every outstanding "remember me" cookie.
      @user.register_successful_login!
      forget_remembered_user
      reset_session

      redirect_to sign_in_path, notice: "Your password has been reset. Please sign in."
    else
      render_invalid(@user.errors.full_messages.to_sentence)
    end
  end

  private

  def set_user_from_token
    @user = User.find_by_token_for(:password_reset, params[:token])

    redirect_to new_password_reset_path, alert: INVALID_TOKEN_ALERT if @user.nil?
  end

  def render_invalid(message)
    flash.now[:alert] = message
    render :edit, status: :unprocessable_entity
  end
end

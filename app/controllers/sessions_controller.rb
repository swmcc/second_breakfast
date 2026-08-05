class SessionsController < ApplicationController
  rate_limit to: 10, within: 3.minutes, only: :create,
             with: -> { redirect_to sign_in_path, alert: "Too many login attempts. Please try again later." }

  def new
  end

  def create
    if (user = authenticate_user)
      login(user)
      redirect_to root_path, notice: "Logged in successfully"
    else
      log_failed_login
      flash.now[:alert] = "Invalid email or password"
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    logout
    redirect_to root_path, notice: "Logged out successfully"
  end

  private

  def authenticate_user
    User.authenticate_by(email: params[:email], password: params[:password])
  end

  def log_failed_login
    Rails.logger.warn("[security] Failed login attempt for #{params[:email].to_s.truncate(100)} from #{request.remote_ip}")
  end

  def login(user)
    reset_session
    session[:user_id] = user.id
  end

  def logout
    reset_session
  end
end

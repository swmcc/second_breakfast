class SessionsController < ApplicationController
  # Deliberately identical to the "wrong password" message: a locked account must
  # not be distinguishable from a bad password or an unknown address.
  GENERIC_FAILURE = "Invalid email or password".freeze

  rate_limit to: 10, within: 3.minutes, only: :create,
             with: -> { redirect_to sign_in_path, alert: "Too many login attempts. Please try again later." }

  def new
  end

  def create
    candidate = User.find_by(email: submitted_email)
    # Always run the digest comparison, even for a locked account, so that a
    # locked account is not distinguishable by how long the response takes.
    user = authenticate_user

    if candidate&.locked?
      log_failed_login("account locked")
      return deny_login
    end

    if user
      user.register_successful_login!
      login(user)
      redirect_to root_path, notice: "Logged in successfully"
    else
      candidate&.register_failed_login!
      log_failed_login("invalid credentials")
      deny_login
    end
  end

  def destroy
    logout
    redirect_to root_path, notice: "Logged out successfully"
  end

  private

  # authenticate_by runs a throwaway digest comparison when no record matches, so
  # a missing account takes the same wall-clock time as a wrong password.
  def authenticate_user
    User.authenticate_by(email: submitted_email, password: params[:password].to_s)
  end

  def submitted_email
    params[:email].to_s
  end

  def deny_login
    flash.now[:alert] = GENERIC_FAILURE
    render :new, status: :unprocessable_entity
  end

  def log_failed_login(reason)
    Rails.logger.warn(
      "[security] Failed login attempt (#{reason}) for #{params[:email].to_s.truncate(100)} from #{request.remote_ip}"
    )
  end

  def login(user)
    reset_session
    session[:user_id] = user.id

    if remember_me?
      remember_user(user)
    else
      forget_remembered_user(user)
    end
  end

  def logout
    forget_remembered_user(current_user)
    reset_session
  end

  def remember_me?
    ActiveModel::Type::Boolean.new.cast(params[:remember_me]).present?
  end
end

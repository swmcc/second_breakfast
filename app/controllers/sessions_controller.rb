class SessionsController < ApplicationController
  def new
  end

  def create
    if (user = authenticate_user)
      login(user)
      redirect_to root_path, notice: "Logged in successfully"
    else
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
    User.find_by(email: params[:email])&.authenticate(params[:password]) || nil
  end

  def login(user)
    session[:user_id] = user.id
  end

  def logout
    session[:user_id] = nil
  end
end

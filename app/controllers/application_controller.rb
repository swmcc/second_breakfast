class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  REMEMBER_ME_COOKIE = :remember_me

  helper_method :current_user, :user_signed_in?

  def current_user
    return @current_user if defined?(@current_user)

    @current_user = user_from_session || user_from_remember_cookie
  end

  def user_signed_in?
    current_user.present?
  end

  def authenticate_user!
    redirect_to sign_in_path, alert: "You must sign in first" unless user_signed_in?
  end

  private

  def user_from_session
    User.find_by(id: session[:user_id]) if session[:user_id]
  end

  # The cookie carries "<user id>:<token>" and is signed, so it cannot be forged.
  # The token itself lives on the user row and is cleared whenever the password
  # changes, which revokes every outstanding cookie for that account.
  def user_from_remember_cookie
    cookie = cookies.signed[REMEMBER_ME_COOKIE]
    return nil if cookie.blank?

    user_id, token = cookie.to_s.split(":", 2)
    user = User.find_by(id: user_id)

    if user&.remember_token_matches?(token)
      user
    else
      forget_remembered_user
      nil
    end
  end

  def remember_user(user)
    cookies.signed.permanent[REMEMBER_ME_COOKIE] = {
      value: "#{user.id}:#{user.remember_me!}",
      httponly: true,
      same_site: :lax,
      secure: request.ssl?
    }
  end

  def forget_remembered_user(user = nil)
    user&.forget_me!
    cookies.delete(REMEMBER_ME_COOKIE)
  end
end

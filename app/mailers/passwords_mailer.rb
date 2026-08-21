class PasswordsMailer < ApplicationMailer
  def reset(user)
    @user = user
    @token = user.generate_token_for(:password_reset)
    @expires_in = User::PASSWORD_RESET_TOKEN_EXPIRY.inspect

    mail to: user.email, subject: "Reset your Second Breakfast password"
  end
end

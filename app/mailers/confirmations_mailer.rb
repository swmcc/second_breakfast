class ConfirmationsMailer < ApplicationMailer
  def confirm(user)
    @user = user
    @token = user.generate_token_for(:email_confirmation)
    @expires_in = User::EMAIL_CONFIRMATION_TOKEN_EXPIRY.inspect

    mail to: user.email, subject: "Confirm your Second Breakfast email address"
  end
end

# frozen_string_literal: true

module AuthenticationHelpers
  def sign_in(user)
    post session_path, params: { email: user.email, password: "password123" }
  end

  def sign_out
    delete sign_out_path
  end
end

RSpec.configure do |config|
  config.include AuthenticationHelpers, type: :request
end

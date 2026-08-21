require "rails_helper"

RSpec.describe ConfirmationsMailer do
  describe "#confirm" do
    subject(:mail) { described_class.confirm(user) }

    let(:user) { create(:user, :unconfirmed, email: "test@example.com") }

    it "is addressed to the user" do
      expect(mail.to).to eq([ "test@example.com" ])
      expect(mail.subject).to eq("Confirm your Second Breakfast email address")
    end

    it "embeds a usable, absolute confirmation URL" do
      token = mail.body.encoded[%r{http://example\.com/email_confirmation/([^/\s"<]+)}, 1]

      expect(token).to be_present
      expect(User.find_by_token_for(:email_confirmation, token)).to eq(user)
    end

    it "never includes the password digest" do
      expect(mail.body.encoded).not_to include(user.password_digest)
    end
  end
end

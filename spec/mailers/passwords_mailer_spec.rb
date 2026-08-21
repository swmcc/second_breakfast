require "rails_helper"

RSpec.describe PasswordsMailer do
  describe "#reset" do
    subject(:mail) { described_class.reset(user) }

    let(:user) { create(:user, email: "test@example.com") }

    it "is addressed to the user" do
      expect(mail.to).to eq([ "test@example.com" ])
      expect(mail.subject).to eq("Reset your Second Breakfast password")
    end

    it "embeds a usable, absolute reset URL" do
      token = mail.body.encoded[%r{http://example\.com/password_resets/([^/\s"<]+)/edit}, 1]

      expect(token).to be_present
      expect(User.find_by_token_for(:password_reset, token)).to eq(user)
    end

    it "never includes the password digest" do
      expect(mail.body.encoded).not_to include(user.password_digest)
    end

    it "states how long the link lasts" do
      expect(mail.body.encoded).to include("15 minutes")
    end
  end
end

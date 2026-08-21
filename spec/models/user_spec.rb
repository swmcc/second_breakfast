require "rails_helper"

RSpec.describe User do
  describe "validations" do
    subject { build(:user) }

    it { is_expected.to validate_presence_of(:email) }
    it { is_expected.to validate_uniqueness_of(:email) }
    it { is_expected.to have_secure_password }
  end

  describe "associations" do
    it { is_expected.to have_many(:baskets).dependent(:destroy) }
    it { is_expected.to have_many(:recipes).through(:baskets) }
  end

  describe "password reset tokens" do
    include ActiveSupport::Testing::TimeHelpers

    let(:user) { create(:user) }

    it "round-trips a freshly generated token" do
      token = user.generate_token_for(:password_reset)

      expect(described_class.find_by_token_for(:password_reset, token)).to eq(user)
    end

    it "expires after the configured window" do
      token = user.generate_token_for(:password_reset)

      travel_to(User::PASSWORD_RESET_TOKEN_EXPIRY.from_now + 1.second) do
        expect(described_class.find_by_token_for(:password_reset, token)).to be_nil
      end
    end

    it "is still valid just inside the window" do
      token = user.generate_token_for(:password_reset)

      travel_to(User::PASSWORD_RESET_TOKEN_EXPIRY.from_now - 1.minute) do
        expect(described_class.find_by_token_for(:password_reset, token)).to eq(user)
      end
    end

    it "is invalidated by a password change" do
      token = user.generate_token_for(:password_reset)

      user.update!(password: "brandnewpassword", password_confirmation: "brandnewpassword")

      expect(described_class.find_by_token_for(:password_reset, token)).to be_nil
    end

    it "rejects a garbage token" do
      expect(described_class.find_by_token_for(:password_reset, "nonsense")).to be_nil
    end

    it "is not accepted as an email confirmation token" do
      token = user.generate_token_for(:password_reset)

      expect(described_class.find_by_token_for(:email_confirmation, token)).to be_nil
    end
  end

  describe "email confirmation tokens" do
    include ActiveSupport::Testing::TimeHelpers

    let(:user) { create(:user, :unconfirmed) }

    it "round-trips a freshly generated token" do
      token = user.generate_token_for(:email_confirmation)

      expect(described_class.find_by_token_for(:email_confirmation, token)).to eq(user)
    end

    it "expires after the configured window" do
      token = user.generate_token_for(:email_confirmation)

      travel_to(User::EMAIL_CONFIRMATION_TOKEN_EXPIRY.from_now + 1.second) do
        expect(described_class.find_by_token_for(:email_confirmation, token)).to be_nil
      end
    end

    it "is invalidated once the account is confirmed" do
      token = user.generate_token_for(:email_confirmation)

      user.confirm!

      expect(described_class.find_by_token_for(:email_confirmation, token)).to be_nil
    end

    it "is invalidated when the email address changes" do
      token = user.generate_token_for(:email_confirmation)

      user.update!(email: "moved@example.com")

      expect(described_class.find_by_token_for(:email_confirmation, token)).to be_nil
    end
  end

  describe "#confirmed? and #confirm!" do
    it "starts unconfirmed" do
      expect(build(:user, :unconfirmed)).not_to be_confirmed
    end

    it "stamps confirmed_at" do
      user = create(:user, :unconfirmed)

      user.confirm!

      expect(user.reload).to be_confirmed
      expect(user.confirmed_at).to be_present
    end

    it "leaves an already confirmed account alone" do
      user = create(:user)
      original = user.confirmed_at

      user.confirm!

      expect(user.reload.confirmed_at).to eq(original)
    end
  end

  describe "account lockout" do
    include ActiveSupport::Testing::TimeHelpers

    let(:user) { create(:user) }

    it "is not locked to begin with" do
      expect(user).not_to be_locked
    end

    it "counts failures below the threshold without locking" do
      (User::MAX_FAILED_LOGIN_ATTEMPTS - 1).times { user.register_failed_login! }

      expect(user.failed_attempts).to eq(User::MAX_FAILED_LOGIN_ATTEMPTS - 1)
      expect(user).not_to be_locked
    end

    it "locks once the threshold is reached" do
      User::MAX_FAILED_LOGIN_ATTEMPTS.times { user.register_failed_login! }

      expect(user).to be_locked
      expect(user.locked_until).to be_within(5.seconds).of(User::LOCKOUT_PERIOD.from_now)
    end

    it "unlocks itself once the cooldown has passed" do
      User::MAX_FAILED_LOGIN_ATTEMPTS.times { user.register_failed_login! }

      travel_to(User::LOCKOUT_PERIOD.from_now + 1.second) do
        expect(user).not_to be_locked
      end
    end

    it "gives a full fresh allowance after the cooldown" do
      User::MAX_FAILED_LOGIN_ATTEMPTS.times { user.register_failed_login! }

      travel_to(User::LOCKOUT_PERIOD.from_now + 1.second) do
        user.register_failed_login!

        expect(user).not_to be_locked
      end
    end

    it "clears the counter and the lock on a successful sign in" do
      User::MAX_FAILED_LOGIN_ATTEMPTS.times { user.register_failed_login! }

      user.register_successful_login!

      expect(user.reload.failed_attempts).to be_zero
      expect(user.locked_until).to be_nil
      expect(user).not_to be_locked
    end
  end

  describe "remember me tokens" do
    let(:user) { create(:user) }

    it "issues a long random token and stores it" do
      token = user.remember_me!

      expect(token.length).to be >= 32
      expect(user.reload.remember_token).to eq(token)
    end

    it "issues a different token each time" do
      first = user.remember_me!

      expect(user.remember_me!).not_to eq(first)
    end

    it "matches the issued token" do
      token = user.remember_me!

      expect(user.remember_token_matches?(token)).to be true
    end

    it "rejects a different token" do
      user.remember_me!

      expect(user.remember_token_matches?("something-else")).to be false
    end

    it "rejects blank candidates" do
      user.remember_me!

      expect(user.remember_token_matches?(nil)).to be false
      expect(user.remember_token_matches?("")).to be false
    end

    it "never matches when no token has been issued" do
      expect(user.remember_token_matches?(nil)).to be false
      expect(user.remember_token_matches?("anything")).to be false
    end

    it "is cleared by #forget_me!" do
      token = user.remember_me!

      user.forget_me!

      expect(user.reload.remember_token).to be_nil
      expect(user.remember_token_matches?(token)).to be false
    end

    it "is revoked when the password changes" do
      token = user.remember_me!

      user.update!(password: "brandnewpassword", password_confirmation: "brandnewpassword")

      expect(user.reload.remember_token).to be_nil
      expect(user.remember_token_matches?(token)).to be false
    end

    it "survives an unrelated update" do
      token = user.remember_me!

      user.update!(email: "still-me@example.com")

      expect(user.reload.remember_token).to eq(token)
    end
  end

  describe "password length" do
    it "rejects a password below the minimum" do
      user = build(:user, password: "short", password_confirmation: "short")

      expect(user).not_to be_valid
      expect(user.errors[:password]).to be_present
    end

    it "accepts a password at the minimum" do
      password = "a" * User::MINIMUM_PASSWORD_LENGTH

      expect(build(:user, password: password, password_confirmation: password)).to be_valid
    end
  end

  describe "#in_basket?" do
    let(:user) { create(:user) }
    let(:recipe) { create(:recipe) }

    context "when recipe is in the user's basket" do
      before { create(:basket, user: user, recipe: recipe) }

      it "returns true" do
        expect(user.in_basket?(recipe)).to be true
      end
    end

    context "when recipe is not in the user's basket" do
      it "returns false" do
        expect(user.in_basket?(recipe)).to be false
      end
    end

    context "when recipe is in another user's basket" do
      let(:other_user) { create(:user) }

      before { create(:basket, user: other_user, recipe: recipe) }

      it "returns false for the first user" do
        expect(user.in_basket?(recipe)).to be false
      end
    end
  end

  describe "#aggregated_ingredients" do
    let(:user) { create(:user) }
    let(:category) { create(:category) }

    context "with no recipes in basket" do
      it "returns an empty array" do
        expect(user.aggregated_ingredients).to eq([])
      end
    end

    context "with one recipe in basket" do
      let(:recipe) do
        create(:recipe, category: category, ingredients: [
          { "name" => "Flour", "quantity" => "2", "unit" => "cups" },
          { "name" => "Sugar", "quantity" => "1", "unit" => "cups" }
        ])
      end

      before { create(:basket, user: user, recipe: recipe) }

      it "returns the ingredients from that recipe" do
        result = user.aggregated_ingredients

        expect(result).to contain_exactly(
          { name: "Flour", quantity: 2.0, unit: "cups" },
          { name: "Sugar", quantity: 1.0, unit: "cups" }
        )
      end
    end

    context "with multiple recipes sharing ingredients" do
      let(:recipe1) do
        create(:recipe, category: category, ingredients: [
          { "name" => "Flour", "quantity" => "2", "unit" => "cups" },
          { "name" => "Eggs", "quantity" => "3", "unit" => "pieces" }
        ])
      end

      let(:recipe2) do
        create(:recipe, category: category, ingredients: [
          { "name" => "Flour", "quantity" => "1", "unit" => "cups" },
          { "name" => "Milk", "quantity" => "2", "unit" => "cups" }
        ])
      end

      before do
        create(:basket, user: user, recipe: recipe1)
        create(:basket, user: user, recipe: recipe2)
      end

      it "aggregates quantities of the same ingredient and unit" do
        result = user.aggregated_ingredients
        flour = result.find { |i| i[:name] == "Flour" }

        expect(flour[:quantity]).to eq(3.0)
        expect(flour[:unit]).to eq("cups")
      end

      it "keeps different ingredients separate" do
        result = user.aggregated_ingredients

        expect(result.map { |i| i[:name] }).to contain_exactly("Flour", "Eggs", "Milk")
      end
    end

    context "with same ingredient but different units" do
      let(:recipe1) do
        create(:recipe, category: category, ingredients: [
          { "name" => "Butter", "quantity" => "2", "unit" => "tbsp" }
        ])
      end

      let(:recipe2) do
        create(:recipe, category: category, ingredients: [
          { "name" => "Butter", "quantity" => "1", "unit" => "cups" }
        ])
      end

      before do
        create(:basket, user: user, recipe: recipe1)
        create(:basket, user: user, recipe: recipe2)
      end

      it "keeps them separate (does not convert units)" do
        result = user.aggregated_ingredients
        butter_items = result.select { |i| i[:name] == "Butter" }

        expect(butter_items.size).to eq(2)
        expect(butter_items).to contain_exactly(
          { name: "Butter", quantity: 2.0, unit: "tbsp" },
          { name: "Butter", quantity: 1.0, unit: "cups" }
        )
      end
    end
  end

  describe "#ingredients_list" do
    let(:user) { create(:user) }
    let(:category) { create(:category) }

    context "with no recipes in basket" do
      it "returns an empty array" do
        expect(user.ingredients_list).to eq([])
      end
    end

    context "with recipes in basket" do
      let(:recipe1) do
        create(:recipe, title: "Pancakes", category: category, ingredients: [
          { "name" => "Flour", "quantity" => "2", "unit" => "cups" }
        ])
      end

      let(:recipe2) do
        create(:recipe, title: "Omelette", category: category, ingredients: [
          { "name" => "Eggs", "quantity" => "3", "unit" => "pieces" }
        ])
      end

      before do
        create(:basket, user: user, recipe: recipe1)
        create(:basket, user: user, recipe: recipe2)
      end

      it "returns a list with recipe names and their ingredients" do
        result = user.ingredients_list

        expect(result).to contain_exactly(
          { recipe_name: "Pancakes", ingredients: recipe1.ingredients },
          { recipe_name: "Omelette", ingredients: recipe2.ingredients }
        )
      end
    end
  end

  describe "destroying a user" do
    let(:user) { create(:user) }
    let(:recipe) { create(:recipe) }

    before { create(:basket, user: user, recipe: recipe) }

    it "also destroys their baskets" do
      expect { user.destroy }.to change(Basket, :count).by(-1)
    end

    it "does not destroy the recipes" do
      expect { user.destroy }.not_to change(Recipe, :count)
    end
  end
end

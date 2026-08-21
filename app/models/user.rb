class User < ApplicationRecord
  # Sign-in hardening (see issue #64).
  MAX_FAILED_LOGIN_ATTEMPTS = 5
  LOCKOUT_PERIOD = 15.minutes
  MINIMUM_PASSWORD_LENGTH = 8
  PASSWORD_RESET_TOKEN_EXPIRY = 15.minutes
  EMAIL_CONFIRMATION_TOKEN_EXPIRY = 1.day

  has_secure_password

  has_many :baskets, dependent: :destroy
  has_many :recipes, through: :baskets
  has_many :api_keys, dependent: :destroy
  has_many :meal_plans, dependent: :destroy

  validates :email, presence: true, uniqueness: true
  validates :password, length: { minimum: MINIMUM_PASSWORD_LENGTH }, allow_nil: true

  # Signed, self-expiring tokens. Nothing is written to the database, and the
  # fingerprint block ties each token to state that changes when the token is
  # used, so a token cannot be replayed.
  #
  # password_salt changes whenever the digest is rewritten, so a reset link dies
  # the moment it is redeemed (or the password is changed by any other means).
  generates_token_for :password_reset, expires_in: PASSWORD_RESET_TOKEN_EXPIRY do
    password_salt&.last(10)
  end

  # Confirming stamps confirmed_at, which invalidates every outstanding link.
  # Including the email means a link is void if the address it was sent to has
  # since been changed.
  generates_token_for :email_confirmation, expires_in: EMAIL_CONFIRMATION_TOKEN_EXPIRY do
    [ email, confirmed_at&.to_i ]
  end

  # Changing the password revokes every "remember me" cookie for this account.
  # This runs as an after_update write rather than a before_save assignment so
  # that it clears the stored token even when the in-memory value is stale.
  after_update :discard_remember_token, if: :saved_change_to_password_digest?

  def self.generate_remember_token
    SecureRandom.urlsafe_base64(32)
  end

  # --- Email confirmation -------------------------------------------------

  def confirmed?
    confirmed_at.present?
  end

  def confirm!
    return true if confirmed?

    update_columns(confirmed_at: Time.current)
  end

  # --- Account lockout ----------------------------------------------------

  def locked?
    locked_until.present? && locked_until.future?
  end

  # Zeroing the counter when we lock means the cooldown expiring gives the
  # account a fresh allowance rather than one attempt before re-locking.
  def register_failed_login!
    attempts = failed_attempts.to_i + 1

    if attempts >= MAX_FAILED_LOGIN_ATTEMPTS
      update_columns(failed_attempts: 0, locked_until: LOCKOUT_PERIOD.from_now)
    else
      update_columns(failed_attempts: attempts)
    end
  end

  def register_successful_login!
    return if failed_attempts.to_i.zero? && locked_until.nil?

    update_columns(failed_attempts: 0, locked_until: nil)
  end

  # --- Remember me --------------------------------------------------------

  def remember_me!
    self.class.generate_remember_token.tap do |token|
      update_columns(remember_token: token)
    end
  end

  def forget_me!
    return if remember_token.nil?

    update_columns(remember_token: nil)
  end

  def remember_token_matches?(candidate)
    return false if remember_token.blank? || candidate.blank?

    ActiveSupport::SecurityUtils.secure_compare(remember_token, candidate.to_s)
  end

  def in_basket?(recipe)
    baskets.exists?(recipe: recipe)
  end

  def aggregated_ingredients
    db_adapter = ActiveRecord::Base.connection.adapter_name.downcase

    if db_adapter.include?("sqlite")
      recipes.joins("JOIN json_each(recipes.ingredients) AS ingredient")
             .select("ingredient.value ->> '$.name' AS name,
                      SUM(CAST(ingredient.value ->> '$.quantity' AS NUMERIC)) AS total_quantity,
                      ingredient.value ->> '$.unit' AS unit")
             .group("name, unit")
             .map { |record| { name: record.name, quantity: record.total_quantity.to_f, unit: record.unit } }
    else
      recipes.joins("CROSS JOIN LATERAL jsonb_array_elements(recipes.ingredients::jsonb) AS ingredient")
             .select("ingredient->>'name' AS name,
                      SUM((ingredient->>'quantity')::NUMERIC) AS total_quantity,
                      ingredient->>'unit' AS unit")
             .group("ingredient->>'name', ingredient->>'unit'")
             .map { |record| { name: record.name, quantity: record.total_quantity.to_f, unit: record.unit } }
    end
  end

  def ingredients_list
    baskets.includes(:recipe).map do |basket|
      {
        recipe_name: basket.recipe.title,
        ingredients: basket.recipe.ingredients
      }
    end
  end

  private

  def discard_remember_token
    update_columns(remember_token: nil)
  end
end

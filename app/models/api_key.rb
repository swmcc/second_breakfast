# frozen_string_literal: true

class ApiKey < ApplicationRecord
  TOUCH_INTERVAL = 1.minute

  belongs_to :user

  validates :name, presence: true

  scope :active, -> { where(revoked_at: nil) }

  # The raw token is only readable on the freshly created instance —
  # it is never persisted and cannot be recovered later.
  attr_reader :token

  before_validation :generate_token, on: :create

  def self.authenticate(raw)
    return nil if raw.blank?

    active.find_by(token_digest: Digest::SHA256.hexdigest(raw))
  end

  def active?
    revoked_at.nil?
  end

  def revoke!
    update!(revoked_at: Time.current)
  end

  def touch_last_used!
    return if last_used_at.present? && last_used_at > TOUCH_INTERVAL.ago

    update_column(:last_used_at, Time.current)
  end

  private

  def generate_token
    return if token_digest.present?

    @token = "sb_#{SecureRandom.hex(32)}"
    self.token_digest = Digest::SHA256.hexdigest(@token)
    self.prefix = @token.first(8)
  end
end

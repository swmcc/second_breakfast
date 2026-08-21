class Review < ApplicationRecord
  MAX_BODY_LENGTH = 2_000

  belongs_to :user
  belongs_to :recipe

  validates :body, presence: true, length: { maximum: MAX_BODY_LENGTH }

  scope :newest_first, -> { order(created_at: :desc) }

  def editable_by?(user)
    user.present? && user_id == user.id
  end
end

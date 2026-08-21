class Recipe < ApplicationRecord
  belongs_to :category

  has_many :baskets, dependent: :destroy
  has_many :users, through: :baskets

  has_rich_text :instructions

  has_one_attached :image

  validates :title, :description, :serves, :instructions, :prep_time, :ingredients, :nutrition, presence: true

  validate :validate_nutrition_format
  validate :acceptable_image

  # --- Sharing, visibility and social (issue #66) -----------------------------

  PUBLIC = "public"
  PRIVATE = "private"
  VISIBILITIES = [ PUBLIC, PRIVATE ].freeze

  # `user` is the recipe's owner. It is nullable: recipes created before
  # ownership existed have no owner and stay world-readable.
  belongs_to :user, optional: true

  has_many :ratings, dependent: :destroy
  has_many :reviews, dependent: :destroy
  has_many :favorites, dependent: :destroy
  has_many :favorited_by_users, through: :favorites, source: :user

  # Non-guessable token behind the shareable /r/:token URL.
  has_secure_token :public_token, length: 24

  validates :visibility, inclusion: { in: VISIBILITIES }

  scope :publicly_visible, -> { where(visibility: PUBLIC) }
  scope :privately_visible, -> { where(visibility: PRIVATE) }

  # Every recipe a given user (possibly nil, i.e. signed out) may read.
  # Expressed as one WHERE clause so it composes with joins/includes/order.
  scope :visible_to, ->(user) {
    if user
      where("recipes.visibility = :public OR recipes.user_id = :user_id", public: PUBLIC, user_id: user.id)
    else
      publicly_visible
    end
  }

  def public_recipe?
    visibility == PUBLIC
  end

  def private_recipe?
    visibility == PRIVATE
  end

  def owned_by?(user)
    user.present? && user_id.present? && user_id == user.id
  end

  # Private recipes are readable through the app's own URLs by their owner only.
  # The /r/:token share link is a deliberate, separate "anyone with the link"
  # grant — see SharedRecipesController.
  def visible_to?(user)
    public_recipe? || owned_by?(user)
  end

  # Ownership was added retroactively, so unowned legacy recipes stay editable
  # by any signed-in user (the pre-existing behaviour). Owned recipes are the
  # owner's alone.
  def editable_by?(user)
    return false if user.blank?

    user_id.nil? || user_id == user.id
  end

  def average_rating
    ratings.average(:value)&.round(2)
  end

  def ratings_count
    ratings.count
  end

  def rating_by(user)
    return nil if user.blank?

    ratings.find_by(user_id: user.id)
  end

  private

  def validate_nutrition_format
    expected_keys = %w[calories protein fat carbs fibre sugar sodium]
    unless nutrition.is_a?(Hash) && (expected_keys - nutrition.keys).empty?
      errors.add(:nutrition, "must include all required fields: #{expected_keys.join(', ')}")
    end
  end

  def acceptable_image
    return unless image.attached?

    allowed_content_types = %w[image/png image/jpeg image/webp image/gif]
    errors.add(:image, "must be a PNG, JPEG, WebP, or GIF") unless image.blob.content_type.in?(allowed_content_types)
    errors.add(:image, "must be smaller than 5 MB") if image.blob.byte_size > 5.megabytes
  end
end

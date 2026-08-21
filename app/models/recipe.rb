class Recipe < ApplicationRecord
  # Short TTL for cached search result ids. Kept in minutes, not hours: the
  # cache key also carries the recipes collection version, so this is only a
  # backstop for anything the version key cannot see.
  SEARCH_CACHE_TTL = 5.minutes

  # touch: true so a recipe change busts any fragment cached against its
  # category (the categories index lists each category's recipes).
  belongs_to :category, touch: true

  has_many :baskets, dependent: :destroy
  has_many :users, through: :baskets

  has_rich_text :instructions

  has_one_attached :image

  validates :title, :description, :serves, :instructions, :prep_time, :ingredients, :nutrition, presence: true

  validate :validate_nutrition_format
  validate :acceptable_image

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

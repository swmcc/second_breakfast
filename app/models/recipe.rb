class Recipe < ApplicationRecord
  has_rich_text :instructions
  validates :title, :description, :serves, :instructions, :prep_time, :ingredients, :nutrition, presence: true

  validate :validate_nutrition_format

  private

  def validate_nutrition_format
    expected_keys = %w[calories protein fat carbs fibre sugar sodium]
    unless nutrition.is_a?(Hash) && (expected_keys - nutrition.keys).empty?
      errors.add(:nutrition, "must include all required fields: #{expected_keys.join(', ')}")
    end
  end
end

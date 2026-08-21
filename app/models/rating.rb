class Rating < ApplicationRecord
  MIN_VALUE = 1
  MAX_VALUE = 5
  VALUES = (MIN_VALUE..MAX_VALUE).to_a.freeze

  belongs_to :user
  belongs_to :recipe

  validates :value,
            presence: true,
            inclusion: { in: VALUES, message: "must be between #{MIN_VALUE} and #{MAX_VALUE}" }
  validates :user_id, uniqueness: { scope: :recipe_id, message: "has already rated this recipe" }
end

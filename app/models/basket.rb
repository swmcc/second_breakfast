class Basket < ApplicationRecord
    # touch: true keeps the user's cache_key_with_version moving whenever their
    # basket changes, which is what busts the cached "Saved Recipes" count in
    # the nav. Fires on create, update and destroy.
    belongs_to :user, touch: true
    belongs_to :recipe

    validates :recipe, uniqueness: { scope: :user, message: "is already in your basket" }
end

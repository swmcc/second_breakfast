class Category < ApplicationRecord
  has_many :recipes

  validates :name, presence: true

  # Cached name/id list for nav, sidebars and the recipe form's category
  # select. The key carries the collection's COUNT + MAX(updated_at) (that is
  # what Relation#cache_key_with_version resolves to), so a category create,
  # update or destroy invalidates it immediately — no TTL required.
  def self.cached_list
    Rails.cache.fetch([ "categories", "list", all.cache_key_with_version ]) do
      order(:name).to_a
    end
  end
end

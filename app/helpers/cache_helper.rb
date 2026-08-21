# frozen_string_literal: true

# Helpers for building fragment cache keys.
#
# The keys deliberately describe *what is on the page* rather than how the
# query that produced it is written, so they survive a change of search or
# listing implementation underneath.
module CacheHelper
  # Cache key for a collection of records.
  #
  # For an ActiveRecord::Relation this resolves to Rails' own
  # `cache_key_with_version`, i.e. a single aggregate query returning
  # COUNT(*) and MAX(updated_at) - so adding, removing or touching any record
  # in the collection invalidates the fragment. A plain Array (or anything
  # already loaded) gets the same two numbers derived in Ruby.
  #
  # Several collections can be passed when a fragment renders data from more
  # than one table (the recipes index prints category names, for instance, so a
  # category rename has to invalidate it).
  #
  # `params[:page]` is folded in so that a paginated listing cannot serve
  # page 2 out of page 1's fragment.
  def collection_cache_key(prefix, *collections)
    [ prefix, *collections.map { |collection| collection_version(collection) }, params[:page].presence ].compact
  end

  private

  def collection_version(collection)
    return collection.cache_key_with_version if collection.respond_to?(:cache_key_with_version)

    records = collection.to_a
    latest = records.filter_map { |record| record.try(:updated_at) }.max
    "#{records.size}-#{latest&.utc&.to_fs(:usec)}"
  end
end

# frozen_string_literal: true

# Fragment caching in specs.
#
# The test environment deliberately keeps `config.cache_store = :null_store` as
# its default: turning real caching on for the whole suite is the fastest way
# to invent order-dependent failures. Specs that actually want to exercise the
# caching layer opt in with the `:caching` tag:
#
#   RSpec.describe "...", :caching, type: :request do
#
# Each such example gets its own throwaway MemoryStore, wired into both
# `Rails.cache` (for low level `Rails.cache.fetch` calls) and the controllers'
# `cache_store` (which is what the `cache` view helper reads and writes), and
# everything is restored - and the store discarded - afterwards.
module CachingSpecHelpers
  module_function

  def controller_classes
    [ ActionController::Base, *ActionController::Base.descendants ]
  end
end

RSpec.configure do |config|
  config.around(:each, :caching) do |example|
    previous_rails_cache = Rails.cache
    previous = CachingSpecHelpers.controller_classes.to_h do |klass|
      [ klass, [ klass.cache_store, klass.perform_caching ] ]
    end

    store = ActiveSupport::Cache::MemoryStore.new

    Rails.cache = store
    previous.each_key do |klass|
      klass.cache_store = store
      klass.perform_caching = true
    end

    begin
      example.run
    ensure
      Rails.cache = previous_rails_cache

      # Controllers loaded lazily *during* the example inherited the temporary
      # store, so restore against the current descendant list rather than the
      # one captured up front - otherwise a later example could quietly read
      # from a store that is no longer Rails.cache.
      default_state = previous[ActionController::Base]
      CachingSpecHelpers.controller_classes.each do |klass|
        cache_store, perform_caching = previous.fetch(klass, default_state)
        klass.cache_store = cache_store
        klass.perform_caching = perform_caching
      end

      store.clear
    end
  end

  # Belt and braces for every other example: never let one example observe a
  # cache entry written by another. A no-op against the null store, and cheap
  # insurance if the test cache store is ever changed.
  config.before(:each) { Rails.cache.clear }
end

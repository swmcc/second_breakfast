# frozen_string_literal: true

require "benchmark"

namespace :cache do
  desc "Time the cached pages cold vs warm (never run against production)"
  task benchmark: :environment do
    abort "Refusing to run against production." if Rails.env.production?

    unless ActionController::Base.perform_caching
      abort "Fragment caching is off. Run `bin/rails dev:cache` (toggles tmp/caching-dev.txt) and retry."
    end

    recipe = Recipe.order(:id).first
    abort "No recipes in this database - seed some first." if recipe.nil?

    query = recipe.title.to_s.split.first.to_s.downcase

    pages = {
      "recipes#index" => "/recipes",
      "recipes#show" => "/recipes/#{recipe.id}",
      "categories#index" => "/categories",
      "recipes#search" => "/recipes/search?query=#{CGI.escape(query)}"
    }

    session = ActionDispatch::Integration::Session.new(Rails.application)
    session.host! "www.example.com"

    puts format("%-18s %10s %10s %10s", "page", "cold (ms)", "warm (ms)", "saved")
    puts "-" * 52

    pages.each do |label, path|
      Rails.cache.clear

      cold = Benchmark.realtime { session.get(path) }
      next puts(format("%-18s %10s", label, "HTTP #{session.response.status}")) unless session.response.status == 200

      warm = Benchmark.realtime { session.get(path) }

      saved = cold.zero? ? 0 : ((cold - warm) / cold * 100).round
      puts format("%-18s %10.1f %10.1f %9d%%", label, cold * 1000, warm * 1000, saved)
    end

    puts
    puts "Cold = empty cache. Warm = every fragment hit. Single process, single"
    puts "request; treat as a local sanity check, not a production measurement."
  end

  desc "Show Solid Cache entry count and size"
  task stats: :environment do
    unless defined?(SolidCache::Entry)
      abort "Solid Cache is not loaded (cache store is #{Rails.cache.class})."
    end

    unless Rails.cache.class.name.to_s.include?("SolidCache")
      abort "The configured cache store is #{Rails.cache.class}, not Solid Cache - nothing to report."
    end

    count = SolidCache::Entry.count
    bytes = SolidCache::Entry.sum(:byte_size)
    oldest = SolidCache::Entry.minimum(:created_at)

    puts "entries: #{count}"
    puts "size:    #{ActiveSupport::NumberHelper.number_to_human_size(bytes)}"
    puts "oldest:  #{oldest || 'n/a'}"
    puts
    puts "Hit rate is not tracked here: it needs request-level metrics from the"
    puts "observability work in issue #68. Once that lands, subscribe to the"
    puts "`cache_read.active_support` notification and emit hit/miss counters."
  end
end

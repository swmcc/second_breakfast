# frozen_string_literal: true

class FetchRecipeImageJob < ApplicationJob
  queue_as :default

  ALLOWED_CONTENT_TYPES = %w[image/png image/jpeg image/webp image/gif].freeze

  def perform(recipe_id, search_query = nil)
    recipe = Recipe.find_by(id: recipe_id)
    return unless recipe
    return if recipe.image.attached?

    query = search_query || recipe.title
    image_data = fetch_image(query)
    return unless image_data

    attach_image(recipe, image_data)
  end

  private

  def fetch_image(query)
    search_query = URI.encode_www_form_component("#{query} recipe")

    # Get DuckDuckGo vqd token
    token_url = "https://duckduckgo.com/?q=#{search_query}&iax=images&ia=images"
    token_response = fetch_with_timeout(token_url)
    return nil unless token_response

    vqd = token_response.body.match(/vqd=([^&"]+)/)&.[](1)
    return nil unless vqd

    # Search images
    api_url = "https://duckduckgo.com/i.js?l=us-en&o=json&q=#{search_query}&vqd=#{vqd}&f=,,,,,&p=1"
    api_response = fetch_with_timeout(api_url)
    return nil unless api_response

    data = JSON.parse(api_response.body)
    results = data["results"]
    return nil if results.blank?

    # Find reasonably sized image
    result = results.find { |r| r["width"].to_i < 1200 && r["width"].to_i > 300 } || results.first
    image_url = result["image"]

    # Download image
    image_response = fetch_with_timeout(image_url)
    return nil unless image_response
    return nil if image_response.body.bytesize > 2_000_000

    content_type = image_response["Content-Type"].to_s.split(";", 2).first.to_s.strip.downcase
    unless content_type.start_with?("image/") && content_type.in?(ALLOWED_CONTENT_TYPES)
      Rails.logger.warn("FetchRecipeImageJob skipped unsupported image Content-Type: #{content_type.presence || 'missing'}")
      return nil
    end

    {
      data: image_response.body,
      content_type: content_type
    }
  rescue StandardError => e
    Rails.logger.error("FetchRecipeImageJob error: #{e.message}")
    nil
  end

  def fetch_with_timeout(url, timeout: 10)
    uri = URI.parse(url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == "https"
    http.open_timeout = timeout
    http.read_timeout = timeout

    request = Net::HTTP::Get.new(uri)
    request["User-Agent"] = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36"

    response = http.request(request)
    response.is_a?(Net::HTTPSuccess) ? response : nil
  rescue StandardError
    nil
  end

  def attach_image(recipe, image_data)
    filename = "recipe_#{recipe.id}_#{Time.current.to_i}.jpg"
    recipe.image.attach(
      io: StringIO.new(image_data[:data]),
      filename: filename,
      content_type: image_data[:content_type]
    )
  end
end

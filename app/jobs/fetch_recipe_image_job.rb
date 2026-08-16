# frozen_string_literal: true

class FetchRecipeImageJob < ApplicationJob
  queue_as :default

  ALLOWED_CONTENT_TYPES = %w[image/png image/jpeg image/webp image/gif].freeze
  MAX_IMAGE_BYTES = 2_000_000
  PEXELS_SEARCH_URL = "https://api.pexels.com/v1/search"

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
    api_key = ENV["PEXELS_API_KEY"]
    if api_key.blank?
      Rails.logger.warn("FetchRecipeImageJob skipped: PEXELS_API_KEY is not set")
      return nil
    end

    image_url = search_pexels(query, api_key)
    return nil unless image_url

    download_image(image_url)
  rescue StandardError => e
    Rails.logger.warn("FetchRecipeImageJob error for #{query.inspect}: #{e.message}")
    nil
  end

  def search_pexels(query, api_key)
    search_term = URI.encode_www_form_component("#{query} recipe")
    response = fetch_with_timeout("#{PEXELS_SEARCH_URL}?query=#{search_term}&per_page=5",
                                  headers: { "Authorization" => api_key })
    unless response
      Rails.logger.warn("FetchRecipeImageJob got no usable response from Pexels for #{query.inspect}")
      return nil
    end

    photos = JSON.parse(response.body)["photos"]
    if photos.blank?
      Rails.logger.warn("FetchRecipeImageJob found no Pexels photos for #{query.inspect}")
      return nil
    end

    photos.first.dig("src", "large")
  end

  def download_image(image_url)
    response = fetch_with_timeout(image_url)
    unless response
      Rails.logger.warn("FetchRecipeImageJob failed to download image from #{image_url}")
      return nil
    end

    if response.body.bytesize > MAX_IMAGE_BYTES
      Rails.logger.warn("FetchRecipeImageJob skipped oversized image (#{response.body.bytesize} bytes) from #{image_url}")
      return nil
    end

    content_type = response["Content-Type"].to_s.split(";", 2).first.to_s.strip.downcase
    unless content_type.start_with?("image/") && content_type.in?(ALLOWED_CONTENT_TYPES)
      Rails.logger.warn("FetchRecipeImageJob skipped unsupported image Content-Type: #{content_type.presence || 'missing'}")
      return nil
    end

    {
      data: response.body,
      content_type: content_type
    }
  end

  def fetch_with_timeout(url, timeout: 10, headers: {})
    uri = URI.parse(url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == "https"
    http.open_timeout = timeout
    http.read_timeout = timeout

    request = Net::HTTP::Get.new(uri)
    request["User-Agent"] = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36"
    headers.each { |key, value| request[key] = value }

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

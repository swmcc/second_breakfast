module RecipesHelper
  # The canonical, non-guessable share URL for a recipe.
  def recipe_share_url(recipe)
    shared_recipe_url(recipe.public_token)
  end

  # Plain share URLs only — no third-party SDKs, which the app's CSP
  # (script-src :self) and importmap setup would not accept anyway.
  def recipe_share_targets(recipe, url = nil)
    url ||= recipe_share_url(recipe)
    title = recipe.title.to_s
    blurb = "#{title} — a recipe on Second Breakfast"

    [
      { name: "X",        href: "https://x.com/intent/post?#{{ text: blurb, url: url }.to_query}" },
      { name: "Facebook", href: "https://www.facebook.com/sharer/sharer.php?#{{ u: url }.to_query}" },
      { name: "Bluesky",  href: "https://bsky.app/intent/compose?#{{ text: "#{blurb} #{url}" }.to_query}" },
      { name: "WhatsApp", href: "https://wa.me/?#{{ text: "#{blurb} #{url}" }.to_query}" },
      { name: "Email",    href: "mailto:?#{{ subject: title, body: "#{blurb}\n\n#{url}" }.to_query}" }
    ]
  end

  # Absolute URL for the recipe image, suitable for og:image. Nil when the
  # recipe has no image attached.
  def recipe_share_image_url(recipe)
    return nil unless recipe.image.attached?

    rails_blob_url(recipe.image)
  end

  def recipe_visibility_options
    [ [ "Public — anyone can find and read it", Recipe::PUBLIC ],
      [ "Private — only you can read it", Recipe::PRIVATE ] ]
  end

  # "4.5" rather than "4.5000000000000000"; nil when nothing has been rated.
  def formatted_average_rating(recipe)
    average = recipe.average_rating
    return nil if average.blank?

    format("%.1f", average)
  end

  # Bold an ingredient when it matches either the free-text query or the
  # ingredient filter the user typed.
  def highlight_ingredient?(ingredient_name, *terms)
    name = ingredient_name.to_s.downcase
    return false if name.blank?

    terms.any? { |term| term.present? && name.include?(term.to_s.downcase) }
  end
end

json.baskets do
  json.array! @baskets do |basket|
    json.id basket.id
    json.recipe do
      json.partial! "api/v1/recipes/recipe", recipe: basket.recipe
    end
    json.added_at basket.created_at.iso8601
  end
end

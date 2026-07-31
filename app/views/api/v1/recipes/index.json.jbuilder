json.recipes do
  json.array! @recipes, partial: "api/v1/recipes/recipe", as: :recipe
end
json.pagination @pagination

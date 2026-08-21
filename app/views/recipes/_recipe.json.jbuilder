json.extract! recipe, :id, :title, :description, :serves, :instructions, :prep_time, :ingredients, :nutrition, :visibility, :created_at, :updated_at
json.share_url shared_recipe_url(recipe.public_token)
json.url recipe_url(recipe, format: :json)

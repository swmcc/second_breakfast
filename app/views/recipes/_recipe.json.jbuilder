json.extract! recipe, :id, :title, :description, :serves, :instructions, :prep_time, :ingredients, :nutrition, :created_at, :updated_at
json.url recipe_url(recipe, format: :json)

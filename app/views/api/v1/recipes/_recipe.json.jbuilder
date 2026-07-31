json.id recipe.id
json.title recipe.title
json.description recipe.description
json.serves recipe.serves
json.prep_time recipe.prep_time
json.ingredients recipe.ingredients
json.nutrition recipe.nutrition
json.instructions recipe.instructions.to_plain_text if recipe.instructions.present?
json.category do
  json.id recipe.category.id
  json.name recipe.category.name
end
json.image_url url_for(recipe.image) if recipe.image.attached?
json.created_at recipe.created_at.iso8601
json.updated_at recipe.updated_at.iso8601

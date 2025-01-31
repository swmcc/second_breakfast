class AddCategoryToRecipes < ActiveRecord::Migration[8.0]
    def change
    add_reference :recipes, :category, foreign_key: true

    reversible do |dir|
      dir.up do
        default_category = Category.first_or_create(name: 'Uncategorized')
        Recipe.update_all(category_id: default_category.id)
      end
    end

    change_column_null :recipes, :category_id, false
  end
end

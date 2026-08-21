class AddSharingToRecipes < ActiveRecord::Migration[8.1]
  # Lightweight stand-in so the backfill does not depend on the app's Recipe
  # model (and its validations) staying compatible with this migration.
  class MigrationRecipe < ActiveRecord::Base
    self.table_name = "recipes"
  end

  def up
    # Recipes had no owner before this migration. The column is nullable so the
    # existing corpus of unowned recipes keeps working; new recipes get an owner.
    add_column :recipes, :user_id, :bigint
    add_index :recipes, :user_id
    add_foreign_key :recipes, :users

    # Everything was world-readable before, so "public" is the value that
    # preserves current behaviour for existing rows.
    add_column :recipes, :visibility, :string, default: "public", null: false
    add_index :recipes, :visibility

    add_column :recipes, :public_token, :string
    MigrationRecipe.reset_column_information
    MigrationRecipe.where(public_token: nil).find_each do |recipe|
      recipe.update_columns(public_token: SecureRandom.hex(16))
    end
    change_column_null :recipes, :public_token, false
    add_index :recipes, :public_token, unique: true
  end

  def down
    remove_index :recipes, :public_token
    remove_column :recipes, :public_token
    remove_index :recipes, :visibility
    remove_column :recipes, :visibility
    remove_foreign_key :recipes, :users
    remove_index :recipes, :user_id
    remove_column :recipes, :user_id
  end
end

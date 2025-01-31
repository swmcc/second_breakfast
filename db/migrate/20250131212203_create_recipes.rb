class CreateRecipes < ActiveRecord::Migration[8.0]
  def change
    create_table :recipes do |t|
      t.string :title
      t.text :description
      t.integer :serves
      t.text :instructions
      t.string :prep_time
      t.json :ingredients
      t.json :nutrition

      t.timestamps
    end
  end
end

class CreateReviews < ActiveRecord::Migration[8.1]
  def change
    create_table :reviews do |t|
      t.references :user, null: false, foreign_key: true
      t.references :recipe, null: false, foreign_key: true
      t.text :body, null: false

      t.timestamps
    end

    add_index :reviews, [ :recipe_id, :created_at ]
  end
end

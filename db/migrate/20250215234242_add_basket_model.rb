class AddBasketModel < ActiveRecord::Migration[8.0]
  def change
    create_table :baskets do |t|
      t.references :user, null: false, foreign_key: true
      t.references :recipe, null: false, foreign_key: true

      t.timestamps
    end

    add_index :baskets, [ :user_id, :recipe_id ], unique: true
  end
end

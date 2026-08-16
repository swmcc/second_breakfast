class CreateMealPlans < ActiveRecord::Migration[8.1]
  def change
    create_table :meal_plans do |t|
      t.references :user, null: false, foreign_key: true
      t.date :week_start_date, null: false
      t.string :status, null: false, default: "draft"

      t.timestamps
    end
    add_index :meal_plans, [ :user_id, :week_start_date ], unique: true
  end
end

class AddAuthHardeningToUsers < ActiveRecord::Migration[8.1]
  def up
    add_column :users, :confirmed_at, :datetime
    add_column :users, :failed_attempts, :integer, default: 0, null: false
    add_column :users, :locked_until, :datetime
    add_column :users, :remember_token, :string

    add_index :users, :remember_token, unique: true

    # Accounts that predate email confirmation are grandfathered in as confirmed
    # so that turning the feature on cannot lock anybody out of their account.
    execute "UPDATE users SET confirmed_at = CURRENT_TIMESTAMP WHERE confirmed_at IS NULL"
  end

  def down
    remove_column :users, :remember_token
    remove_column :users, :locked_until
    remove_column :users, :failed_attempts
    remove_column :users, :confirmed_at
  end
end

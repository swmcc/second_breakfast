class BackfillLegacyApiKeys < ActiveRecord::Migration[8.1]
  # Inline models so the migration keeps working however the app models evolve.
  class MigrationUser < ActiveRecord::Base
    self.table_name = "users"
  end

  class MigrationApiKey < ActiveRecord::Base
    self.table_name = "api_keys"
  end

  def up
    MigrationUser.where.not(api_token: nil).find_each do |user|
      MigrationApiKey.create!(
        user_id: user.id,
        name: "Legacy key",
        token_digest: Digest::SHA256.hexdigest(user.api_token),
        prefix: user.api_token[0, 8]
      )
    end
  end

  def down
    MigrationApiKey.where(name: "Legacy key").delete_all
  end
end

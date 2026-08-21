class AddFullTextSearchToRecipes < ActiveRecord::Migration[8.1]
  # Weighted search document built from the columns that live on `recipes`
  # itself. ActionText instructions live in `action_text_rich_texts`, so they
  # get their own expression index below and are combined at query time.
  #
  # Ingredients are stored as a JSON array of {name, quantity, unit}. Only the
  # names are worth indexing, so the quantity/unit pairs and the JSON keys are
  # stripped out before tokenising — otherwise "grams" or "2" would match
  # nearly every recipe.
  SEARCHABLE_SQL = <<~SQL.squish
    setweight(to_tsvector('english', coalesce(title, '')), 'A') ||
    setweight(to_tsvector('english', coalesce(description, '')), 'B') ||
    setweight(to_tsvector('english', regexp_replace(regexp_replace(coalesce(ingredients::text, ''), '"(quantity|unit)"\\s*:\\s*("[^"]*"|[^,}]*)', ' ', 'g'), '"name"\\s*:', ' ', 'g')), 'C') ||
    setweight(to_tsvector('english', coalesce(instructions, '')), 'D')
  SQL

  RICH_TEXT_SQL = <<~SQL.squish
    to_tsvector('english', regexp_replace(coalesce(body, ''), '<[^>]*>', ' ', 'g'))
  SQL

  RICH_TEXT_INDEX = "index_action_text_rich_texts_on_body_tsvector".freeze
  LOWER_TITLE_INDEX = "index_recipes_on_lower_title".freeze

  def change
    add_column :recipes, :searchable, :tsvector, as: SEARCHABLE_SQL, stored: true
    add_index :recipes, :searchable, using: :gin

    # Expression indexes cannot be auto-inverted, so spell out both directions.
    reversible do |dir|
      dir.up do
        add_index :action_text_rich_texts, RICH_TEXT_SQL, using: :gin, name: RICH_TEXT_INDEX
        add_index :recipes, "LOWER(title)", name: LOWER_TITLE_INDEX
      end

      dir.down do
        remove_index :recipes, name: LOWER_TITLE_INDEX
        remove_index :action_text_rich_texts, name: RICH_TEXT_INDEX
      end
    end

    # Backs the "newest" sort option.
    add_index :recipes, :created_at
  end
end

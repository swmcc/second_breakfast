class Recipe < ApplicationRecord
  # touch: true so a recipe change busts any fragment cached against its
  # category (the categories index lists each category's recipes).
  belongs_to :category, touch: true

  has_many :baskets, dependent: :destroy
  has_many :users, through: :baskets

  has_rich_text :instructions

  has_one_attached :image

  validates :title, :description, :serves, :instructions, :prep_time, :ingredients, :nutrition, presence: true

  validate :validate_nutrition_format
  validate :acceptable_image

  # --- Sharing, visibility and social (issue #66) -----------------------------

  PUBLIC = "public"
  PRIVATE = "private"
  VISIBILITIES = [ PUBLIC, PRIVATE ].freeze

  # `user` is the recipe's owner. It is nullable: recipes created before
  # ownership existed have no owner and stay world-readable.
  belongs_to :user, optional: true

  has_many :ratings, dependent: :destroy
  has_many :reviews, dependent: :destroy
  has_many :favorites, dependent: :destroy
  has_many :favorited_by_users, through: :favorites, source: :user

  # Non-guessable token behind the shareable /r/:token URL.
  has_secure_token :public_token, length: 24

  validates :visibility, inclusion: { in: VISIBILITIES }

  scope :publicly_visible, -> { where(visibility: PUBLIC) }
  scope :privately_visible, -> { where(visibility: PRIVATE) }

  # Every recipe a given user (possibly nil, i.e. signed out) may read.
  # Expressed as one WHERE clause so it composes with joins/includes/order.
  scope :visible_to, ->(user) {
    if user
      where("recipes.visibility = :public OR recipes.user_id = :user_id", public: PUBLIC, user_id: user.id)
    else
      publicly_visible
    end
  }

  def public_recipe?
    visibility == PUBLIC
  end

  def private_recipe?
    visibility == PRIVATE
  end

  def owned_by?(user)
    user.present? && user_id.present? && user_id == user.id
  end

  # Private recipes are readable through the app's own URLs by their owner only.
  # The /r/:token share link is a deliberate, separate "anyone with the link"
  # grant — see SharedRecipesController.
  def visible_to?(user)
    public_recipe? || owned_by?(user)
  end

  # Ownership was added retroactively, so unowned legacy recipes stay editable
  # by any signed-in user (the pre-existing behaviour). Owned recipes are the
  # owner's alone.
  def editable_by?(user)
    return false if user.blank?

    user_id.nil? || user_id == user.id
  end

  def average_rating
    ratings.average(:value)&.round(2)
  end

  def ratings_count
    ratings.count
  end

  def rating_by(user)
    return nil if user.blank?

    ratings.find_by(user_id: user.id)
  end
  # ---------------------------------------------------------------------------
  # Full-text search
  # ---------------------------------------------------------------------------
  #
  # `recipes.searchable` is a stored, generated tsvector column (see
  # db/migrate/*_add_full_text_search_to_recipes.rb) covering title (weight A),
  # description (B) and ingredient names (C), backed by a GIN index. The
  # ActionText instructions body lives in `action_text_rich_texts`, so it has
  # its own GIN expression index and is matched through a UNION sub-select:
  # writing it as `recipes.searchable @@ q OR rich_text_tsv @@ q` across the
  # join would force a sequential scan, whereas the UNION lets Postgres use
  # both GIN indexes. Ranking still uses the joined body so instruction hits
  # score below title/description hits.

  SORT_OPTIONS = %w[relevance newest alphabetical].freeze

  RICH_TEXT_TSVECTOR = <<~SQL.squish.freeze
    setweight(to_tsvector('english', regexp_replace(coalesce(action_text_rich_texts.body, ''), '<[^>]*>', ' ', 'g')), 'D')
  SQL

  FULL_TEXT_MATCH = <<~SQL.squish.freeze
    recipes.id IN (
      SELECT candidate.id
      FROM recipes candidate
      WHERE candidate.searchable @@ plainto_tsquery('english', :term)
      UNION
      SELECT rich_text.record_id
      FROM action_text_rich_texts rich_text
      WHERE rich_text.record_type = 'Recipe'
        AND rich_text.name = 'instructions'
        AND to_tsvector('english', regexp_replace(coalesce(rich_text.body, ''), '<[^>]*>', ' ', 'g'))
            @@ plainto_tsquery('english', :term)
    )
  SQL

  # Ingredients are a JSON array of {name, quantity, unit}; only names match.
  INGREDIENT_NAME_MATCH = <<~SQL.squish.freeze
    EXISTS (
      SELECT 1
      FROM json_array_elements(
        CASE WHEN json_typeof(coalesce(recipes.ingredients, '[]'::json)) = 'array'
             THEN recipes.ingredients
             ELSE '[]'::json
        END
      ) AS ingredient
      WHERE ingredient ->> 'name' ILIKE :pattern
    )
  SQL

  # Returns an ActiveRecord::Relation so callers can chain (and paginate) it.
  #
  #   Recipe.search("pancakes", category_ids: [ 1, 2 ], sort: "newest")
  #
  # A blank query is not an error: filters and sorting still apply, which is
  # what the search page does when someone only picks a category.
  def self.search(query = nil, category_ids: nil, ingredient: nil, sort: nil)
    term = query.to_s.strip
    resolved_sort = resolve_sort(sort, term)

    # The join is only needed to rank instruction hits.
    scope = resolved_sort == "relevance" ? left_joins(:rich_text_instructions) : all
    scope = scope.matching_text(term) if term.present?
    scope = scope.in_categories(category_ids)
    scope = scope.with_ingredient(ingredient)
    scope.sorted_for_search(resolved_sort, term)
  end

  def self.matching_text(term)
    where(FULL_TEXT_MATCH, term: term)
  end

  def self.in_categories(category_ids)
    ids = Array.wrap(category_ids).filter_map { |id| Integer(id, exception: false) }
    ids.any? ? where(category_id: ids) : all
  end

  def self.with_ingredient(name)
    term = name.to_s.strip
    return all if term.blank?

    where(INGREDIENT_NAME_MATCH, pattern: "%#{sanitize_sql_like(term)}%")
  end

  def self.sorted_for_search(sort, term = nil)
    case resolve_sort(sort, term)
    when "alphabetical" then order(Arel.sql("LOWER(recipes.title) ASC")).order(id: :asc)
    when "relevance"    then order(relevance_ordering(term)).order(created_at: :desc, id: :desc)
    else                     order(created_at: :desc, id: :desc)
    end
  end

  # `sort` comes straight from user input, so it is matched against a
  # whitelist and never interpolated into SQL. Relevance only means something
  # when there is a query to rank against, so it degrades to newest.
  def self.resolve_sort(sort, term = nil)
    sort = sort.to_s
    sort = term.present? ? "relevance" : "newest" unless SORT_OPTIONS.include?(sort)
    sort == "relevance" && term.blank? ? "newest" : sort
  end

  def self.relevance_ordering(term)
    Arel.sql(
      sanitize_sql_array([
        "ts_rank((recipes.searchable || #{RICH_TEXT_TSVECTOR}), plainto_tsquery('english', ?)) DESC",
        term
      ])
    )
  end
  private_class_method :relevance_ordering

  private

  def validate_nutrition_format
    expected_keys = %w[calories protein fat carbs fibre sugar sodium]
    unless nutrition.is_a?(Hash) && (expected_keys - nutrition.keys).empty?
      errors.add(:nutrition, "must include all required fields: #{expected_keys.join(', ')}")
    end
  end

  def acceptable_image
    return unless image.attached?

    allowed_content_types = %w[image/png image/jpeg image/webp image/gif]
    errors.add(:image, "must be a PNG, JPEG, WebP, or GIF") unless image.blob.content_type.in?(allowed_content_types)
    errors.add(:image, "must be smaller than 5 MB") if image.blob.byte_size > 5.megabytes
  end
end

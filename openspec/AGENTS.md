# Second Breakfast - AI Agent Instructions

## Quick Reference Commands

```bash
# Development
make local.setup          # Full setup
make local.run            # Start server (bin/dev)
make local.test           # Run tests
make console              # Rails console

# Quality
make lint                 # RuboCop check
make lint.fix             # Auto-fix issues
make local.brakeman       # Security scan

# Database
make local.db.migrate     # Run migrations
make local.db.seed        # Seed data
make local.db.reset       # Full database reset
```

## Key Files

| Purpose | File Path |
|---------|-----------|
| Routes | `config/routes.rb` |
| Database Schema | `db/schema.rb` |
| Seeds | `db/seeds.rb` |
| Recipe Model | `app/models/recipe.rb` |
| User Model | `app/models/user.rb` |
| Basket Model | `app/models/basket.rb` |
| Category Model | `app/models/category.rb` |
| Auth Logic | `app/controllers/application_controller.rb` |
| Recipe Controller | `app/controllers/recipes_controller.rb` |
| Basket Controller | `app/controllers/baskets_controller.rb` |
| Gemfile | `Gemfile` |
| RuboCop Config | `.rubocop.yml` |
| Makefile | `Makefile` |

## Implementation Guidelines

### Adding New Features

1. **Create migration first** - Use `bin/rails generate migration`
2. **Update model** - Add validations, associations, methods
3. **Update routes** - Add RESTful routes in `config/routes.rb`
4. **Create controller** - Follow existing patterns
5. **Add views** - Use Tailwind CSS, follow existing layout
6. **Write tests** - Cover model validations and controller actions
7. **Run quality checks** - `make lint` and `make local.brakeman`

### Authentication Pattern

```ruby
# In ApplicationController:
helper_method :current_user, :user_signed_in?

def current_user
  @current_user ||= User.find_by(id: session[:user_id]) if session[:user_id]
end

def user_signed_in?
  current_user.present?
end

def authenticate_user!
  redirect_to sign_in_path, alert: "You must sign in first" unless user_signed_in?
end
```

Use `before_action :authenticate_user!` to protect actions.

### JSON Column Handling

Recipes use JSON columns for ingredients and nutrition. For PostgreSQL:

```ruby
# Query JSON data
Recipe.where("ingredients::jsonb @> ?", [{ name: "eggs" }].to_json)

# Aggregate ingredients across recipes (User model)
recipes.joins("CROSS JOIN LATERAL jsonb_array_elements(recipes.ingredients::jsonb) AS ingredient")
       .select("ingredient->>'name' AS name, ...")
```

### Adding Recipe Attributes

1. Create migration: `bin/rails g migration AddColumnToRecipes column:type`
2. Update `Recipe` model validations
3. Update `recipe_params` in controller
4. Update form view and show view
5. Update seeds if needed

### Tailwind CSS Patterns

Use existing component patterns:
- Cards: `rounded-lg bg-white shadow`
- Buttons: `rounded-md px-3.5 py-2.5 bg-blue-600 hover:bg-blue-500 text-white`
- Forms: `block w-full rounded-md border-0 py-1.5`
- Badges: `inline-flex items-center rounded-full bg-green-50 px-2 py-1`

## Common Tasks

### Add a New Recipe Field

```bash
# 1. Generate migration
bin/rails g migration AddCookTimeToRecipes cook_time:string

# 2. Run migration
make local.db.migrate

# 3. Update model validation in app/models/recipe.rb

# 4. Add to recipe_params in app/controllers/recipes_controller.rb

# 5. Update form partial app/views/recipes/_form.html.erb

# 6. Update show view app/views/recipes/show.html.erb
```

### Add User Feature (Protected)

```ruby
# Controller
class NewFeaturesController < ApplicationController
  before_action :authenticate_user!

  def index
    @items = current_user.items
  end
end
```

### Search Implementation

Recipe search supports title and ingredient search:

```ruby
def search
  if params[:query].present?
    query = "%#{params[:query]}%"
    @recipes = Recipe.where(
      "LOWER(title) LIKE LOWER(?) OR LOWER(ingredients::text) LIKE LOWER(?)",
      query, query
    )
  end
end
```

### Testing Patterns

```ruby
# Model test
class RecipeTest < ActiveSupport::TestCase
  test "should not save recipe without title" do
    recipe = Recipe.new
    assert_not recipe.save
  end
end

# Controller test
class RecipesControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get recipes_url
    assert_response :success
  end
end
```

## Gotchas

1. **JSON columns** - Use `::jsonb` casting for PostgreSQL queries
2. **Authentication** - Use `before_action :authenticate_user!` not custom logic
3. **Form params** - Nutrition fields need manual handling in controller
4. **Images** - Use Active Storage variants for thumbnails: `recipe.image.variant(resize_to_limit: [200, 200])`
5. **Signed in check** - Views use `signed_in?`, controllers use `user_signed_in?`

## Deployment Checklist

1. Run `make lint` - fix any issues
2. Run `make local.brakeman` - no warnings
3. Run `make local.test` - all passing
4. Commit with gitmoji format
5. Push to origin
6. Deploy: `make deploy`

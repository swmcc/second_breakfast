# Second Breakfast - Project Conventions

## Overview

Second Breakfast is a recipe discovery and meal planning application. Users can browse recipes, add them to their basket (meal plan), and generate aggregated shopping lists from their selected meals.

## Tech Stack

| Component | Technology |
|-----------|------------|
| Framework | Ruby on Rails 8.1 |
| Ruby | 3.3.1 |
| Database | PostgreSQL |
| Frontend | Tailwind CSS, Hotwire (Turbo + Stimulus) |
| Asset Pipeline | Propshaft |
| JavaScript | Importmap (ESM) |
| Rich Text | Action Text |
| File Storage | Active Storage |
| Background Jobs | Solid Queue |
| Caching | Solid Cache |
| WebSockets | Solid Cable |
| Deployment | Docker + Kamal |
| Security Scanning | Brakeman |
| Linting | RuboCop (Rails Omakase) |

## Architecture

### MVC Structure

```
app/
├── controllers/
│   ├── application_controller.rb   # Base controller with auth helpers
│   ├── baskets_controller.rb       # Meal basket management
│   ├── categories_controller.rb    # Recipe categories CRUD
│   ├── pages_controller.rb         # Static pages (random recipe)
│   ├── recipes_controller.rb       # Recipe CRUD and search
│   ├── sessions_controller.rb      # Authentication
│   └── users_controller.rb         # User registration
├── models/
│   ├── basket.rb                   # User-Recipe join model
│   ├── category.rb                 # Recipe categorization
│   ├── recipe.rb                   # Core recipe model
│   └── user.rb                     # User with bcrypt auth
└── views/
    ├── baskets/                    # Meal plan view
    ├── categories/                 # Category views
    ├── layouts/                    # Application layouts
    ├── pages/                      # Homepage
    ├── recipes/                    # Recipe views
    ├── sessions/                   # Login form
    └── users/                      # Registration form
```

### Data Model

```
┌─────────────┐       ┌─────────────┐       ┌─────────────┐
│   User      │       │   Basket    │       │   Recipe    │
├─────────────┤       ├─────────────┤       ├─────────────┤
│ id          │◄──────│ user_id     │       │ id          │
│ email       │       │ recipe_id   │──────►│ title       │
│ password    │       │ created_at  │       │ description │
│             │       │ updated_at  │       │ serves      │
└─────────────┘       └─────────────┘       │ prep_time   │
                                            │ instructions│
                                            │ ingredients │ (JSON)
                                            │ nutrition   │ (JSON)
                                            │ category_id │
                                            └──────┬──────┘
                                                   │
                                            ┌──────▼──────┐
                                            │  Category   │
                                            ├─────────────┤
                                            │ id          │
                                            │ name        │
                                            └─────────────┘
```

### JSON Data Structures

**Ingredients Format:**
```json
[
  { "name": "flour", "quantity": 200, "unit": "grams" },
  { "name": "eggs", "quantity": 2, "unit": "large" }
]
```

**Nutrition Format:**
```json
{
  "calories": 500,
  "protein": 12,
  "fat": 18,
  "carbs": 70,
  "fibre": 2,
  "sugar": 10,
  "sodium": 400
}
```

## Git Commit Conventions

Use gitmoji format for commit messages. See https://gitmoji.dev/

| Emoji | Code | Usage |
|-------|------|-------|
| :sparkles: | `:sparkles:` | New feature |
| :bug: | `:bug:` | Bug fix |
| :memo: | `:memo:` | Documentation |
| :lipstick: | `:lipstick:` | UI/styling |
| :recycle: | `:recycle:` | Refactor |
| :white_check_mark: | `:white_check_mark:` | Tests |
| :lock: | `:lock:` | Security |
| :arrow_up: | `:arrow_up:` | Upgrade dependencies |
| :wrench: | `:wrench:` | Configuration |
| :fire: | `:fire:` | Remove code/files |
| :truck: | `:truck:` | Move/rename |
| :construction: | `:construction:` | Work in progress |
| :rotating_light: | `:rotating_light:` | Fix linter warnings |

**Examples:**
```
:sparkles: Add recipe search by ingredient
:bug: Fix shopping list aggregation for duplicate ingredients
:memo: Update README with deployment instructions
:lipstick: Improve recipe card responsive layout
```

## Code Conventions

### Ruby/Rails Style

- Follow Rails Omakase style (RuboCop)
- Use `has_secure_password` for authentication
- Session-based authentication (no tokens)
- Strong parameters for all controllers
- Use concerns for shared model/controller logic

### Naming Conventions

| Type | Convention | Example |
|------|------------|---------|
| Models | Singular, CamelCase | `Recipe`, `Category` |
| Controllers | Plural, CamelCase + Controller | `RecipesController` |
| Views | Plural directory, snake_case file | `recipes/show.html.erb` |
| Helpers | Plural + Helper | `RecipesHelper` |
| Database tables | Plural, snake_case | `recipes`, `baskets` |
| Routes | RESTful resources | `resources :recipes` |

### View Conventions

- Use Tailwind CSS utility classes
- ERB templates with partials for reuse
- Use `content_for` for page-specific content
- Helper methods: `current_user`, `user_signed_in?`, `signed_in?`

### Testing

- Rails default test framework (Minitest)
- System tests for full integration
- Model validations tested
- Controller tests for auth flows

## Commands

### Development

| Command | Description |
|---------|-------------|
| `make local.setup` | Full setup (gems, db create, migrate, seed) |
| `make local.run` | Start development server (bin/dev) |
| `make local.test` | Run test suite |
| `make console` | Rails console |
| `make lint` | Run RuboCop |
| `make lint.fix` | Auto-fix linting issues |
| `make local.brakeman` | Security scan |

### Database

| Command | Description |
|---------|-------------|
| `make local.db.create` | Create database |
| `make local.db.migrate` | Run migrations |
| `make local.db.seed` | Seed database |
| `make local.db.reset` | Drop, create, migrate, seed |
| `make local.db.status` | Show migration status |

### Deployment

| Command | Description |
|---------|-------------|
| `make deploy.check` | Verify deployment config |
| `make deploy.setup` | Initial infrastructure setup |
| `make deploy` | Deploy to production |

### Direct Rails Commands

```bash
bin/dev                  # Start with Procfile.dev
bin/rails server         # Just the Rails server
bin/rails console        # Interactive console
bin/rails routes         # Show all routes
bin/rails test           # Run tests
bin/rails test:system    # Run system tests
```

## Environment

### Default Development User

- Email: `me@swm.cc`
- Password: `pass5577`

### Routes Overview

| Route | Method | Controller#Action | Purpose |
|-------|--------|-------------------|---------|
| `/` | GET | pages#random_recipe | Homepage with random recipe |
| `/recipes` | GET | recipes#index | List all recipes |
| `/recipes/search` | GET | recipes#search | Search recipes |
| `/recipes/:id` | GET | recipes#show | View recipe |
| `/recipes/new` | GET | recipes#new | New recipe form |
| `/chosen_meals` | GET | baskets#index | View meal plan & shopping list |
| `/baskets/toggle` | POST | baskets#toggle | Add/remove from basket |
| `/sign_in` | GET | sessions#new | Login form |
| `/session` | POST | sessions#create | Login |
| `/sign_out` | DELETE | sessions#destroy | Logout |
| `/users/new` | GET | users#new | Registration form |
| `/categories` | GET | categories#index | List categories |

# Second Breakfast

<p align="center">
  <img src="docs/images/banner.svg" alt="Second Breakfast - Recipe Discovery & Meal Planning" width="600"/>
</p>

A recipe discovery and meal planning application built with Ruby on Rails. Browse recipes, add them to your basket, and generate aggregated shopping lists for your chosen meals.

## Features

- **Recipe Browsing** - Browse recipes with search by title and ingredients
- **Categories** - Organized by meal type (Breakfast, Main Course, Dessert)
- **Meal Planning** - Add recipes to your basket to plan meals
- **Smart Shopping Lists** - Automatically aggregates ingredients across selected recipes
- **Rich Content** - Full recipe details with images, prep time, servings, and nutrition info

## Tech Stack

- **Framework:** Ruby on Rails 8.1
- **Ruby:** 3.3.1
- **Database:** PostgreSQL
- **Frontend:** Tailwind CSS, Hotwire (Turbo + Stimulus)
- **Background Jobs:** Solid Queue
- **Caching:** Solid Cache
- **Deployment:** Docker + Kamal

## Getting Started

### Prerequisites

- Ruby 3.3.1
- PostgreSQL
- Node.js

### Setup

```bash
# Install dependencies and set up database
make local.setup

# Or manually:
bundle install
bin/rails db:create db:migrate db:seed
```

### Running the App

```bash
make local.run
# or
bin/dev
```

Visit http://localhost:3000

### Default User

After seeding, you can log in with:
- Email: `me@swm.cc`
- Password: `pass5577`

## Development Commands

| Command | Description |
|---------|-------------|
| `make local.setup` | Full setup (gems, db create, migrate, seed) |
| `make local.run` | Start the development server |
| `make local.test` | Run the test suite |
| `make console` | Rails console |
| `make lint` | Run RuboCop |
| `make local.brakeman` | Security scan |
| `make local.db.migrate` | Run pending migrations |
| `make local.db.seed` | Seed the database |

## Project Structure

```
app/
├── controllers/    # Request handling
├── models/         # User, Recipe, Basket, Category
├── views/          # ERB templates
└── javascript/     # Stimulus controllers

config/             # Rails configuration
db/                 # Migrations and seeds
```

## Database Schema

- **users** - Authentication and user accounts
- **recipes** - Recipe data with JSON ingredients and nutrition
- **categories** - Recipe categorization
- **baskets** - User recipe selections (join table)

## API

Interactive API documentation available at [/api-docs](/api-docs) (Swagger UI).

### Endpoints

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| GET | `/api/v1/recipes` | No | List recipes (paginated) |
| GET | `/api/v1/recipes/:id` | No | Show recipe |
| GET | `/api/v1/recipes/search?query=` | No | Search recipes |
| POST | `/api/v1/recipes` | Yes | Create recipe |
| PUT | `/api/v1/recipes/:id` | Yes | Update recipe |
| DELETE | `/api/v1/recipes/:id` | Yes | Delete recipe |
| GET | `/api/v1/categories` | No | List categories |
| GET | `/api/v1/categories/:id` | No | Category with recipes |
| GET | `/api/v1/baskets` | Yes | User's basket |
| POST | `/api/v1/baskets` | Yes | Add recipe to basket |
| DELETE | `/api/v1/baskets/:id` | Yes | Remove from basket |

### Authentication

Authenticated endpoints require a Bearer token in the Authorization header:

```
Authorization: Bearer your_api_token
```

Generate an API token via the Rails console:
```ruby
user = User.find_by(email: "your@email.com")
user.generate_api_token!
```

## Deployment

Deployed using Kamal with Docker containers. See `config/deploy.yml` for configuration.

```bash
kamal setup    # Initial deployment
kamal deploy   # Deploy updates
```

## License

Private project.

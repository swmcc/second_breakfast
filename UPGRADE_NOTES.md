# Rails 8.1 Upgrade - Second Breakfast

## Upgrade Summary

Successfully upgraded Second Breakfast from Rails 8.0.1 to Rails 8.1.1 on **2025-05-02**.

## What Changed

### Core Upgrades
- **Ruby**: 3.3.0 → 3.3.1
- **Rails**: 8.0.1 → 8.1.1
- **Database**: SQLite → PostgreSQL (all environments)
- **Tailwind CSS**: 4.2.0 → 3.3.2 (standardized with funeralsni)
- **Solid Queue**: 1.1.5 → 1.2.4

### Database Migration
- Migrated from SQLite to PostgreSQL for development and test environments
- Production was already using PostgreSQL
- Database names:
  - Development: `second_breakfast_development`
  - Test: `second_breakfast_test`
  - Production: Uses DATABASE_URL environment variable

### New Makefile
Created comprehensive Makefile with RVM support for common development tasks:
- `make help` - Show all available commands
- `make local.run` - Run the app with bin/dev
- `make local.setup` - Full setup (install, create db, migrate, seed)
- `make console` - Rails console
- `make local.db.*` - Database commands (create, migrate, seed, etc.)
- `make lint` / `make lint.fix` - RuboCop linting
- `make version` - Show Ruby, Rails, and Bundler versions

## Files Modified

- `Gemfile` - Updated Rails version and removed sqlite3
- `.ruby-version` - Updated to ruby-3.3.1
- `config/database.yml` - Converted to PostgreSQL for all environments
- `Makefile` - New file with comprehensive development commands

## Current Status

✅ Rails 8.1.1 running
✅ Ruby 3.3.1 running
✅ PostgreSQL databases created and migrated
✅ Database seeded with sample data (3 categories, 5 recipes, 1 user)
✅ All routes working
✅ Application loads without errors
✅ Makefile commands functional

## Data Seeded

The database was seeded with:
- 3 categories
- 5 recipes
- 1 user

## Quick Start

To run the application:

```bash
make local.run
```

Or use the traditional Rails command:

```bash
bin/dev
```

The application will be available at http://localhost:3000

## Notes

- RVM is configured to use Ruby 3.3.1
- You may see PATH warnings from RVM - these are informational and don't affect functionality
- Tailwindcss-rails was downgraded to 3.3.2 to match the funeralsni project setup
- All Solid gems (solid_cache, solid_queue, solid_cable) are configured for production use

---

# Deferred: pagy v43 (issue #124)

**Decision (2026-08-21): stay on pagy 9.x.** The Gemfile pins `gem "pagy", "~> 9.4"`
and `.github/dependabot.yml` ignores `version-update:semver-major` for pagy, so
Dependabot will keep proposing 9.x patches but stop proposing v43.

## Why we pinned

Dependabot proposed pagy 9.4.0 -> 43.6.1 (PR #121). That is not a routine bump: v43 is
a full redesign of the public API, and every pagination call site in this app uses the
old one. Pinning keeps the JSON API stable and buys time to do the migration as a
deliberate piece of work rather than as a merged dependency PR.

`pagy` has no 10.x-42.x releases; 9.4.0 is the last release of the 9 series, so the pin
is effectively "frozen at the last stable version of the old API".

## What pagy v43 changes

| pagy 9.x (what we use) | pagy v43 |
|---|---|
| `include Pagy::Backend` | `include Pagy::Method` |
| `@pagy, @records = pagy(scope)` | `@pagy, @records = pagy(:offset, scope)` |
| `Pagy::DEFAULT[:limit] = 20` | `Pagy::OPTIONS[:limit] = 20` |
| `require "pagy/extras/metadata"` / `require "pagy/extras/overflow"` | extras are autoloaded; the explicit requires are removed |
| `include Pagy::Frontend` in helpers, `pagy_nav(@pagy)` | frontend helpers moved/renamed under the new `Pagy::Method` surface |
| Instance readers (`pagy.page`, `pagy.pages`, `pagy.count`, `pagy.limit`) | mostly retained, but signatures around `vars`/options changed - re-verify each one |

Upstream guide: https://ddnexus.github.io/pagy/guides/upgrade-guide/

## What would have to change here when we do upgrade

Current pagy touch points:

- `Gemfile` - the `~> 9.4` pin.
- `.github/dependabot.yml` - remove the pagy `ignore` entry.
- `config/initializers/pagy.rb` - drop the two `require "pagy/extras/..."` lines and
  move `Pagy::DEFAULT[:limit]` / `Pagy::DEFAULT[:overflow]` to `Pagy::OPTIONS`.
- `app/controllers/api/v1/base_controller.rb` - `include Pagy::Backend` becomes
  `include Pagy::Method`; `rescue_from Pagy::OverflowError` needs re-checking against
  the v43 overflow handling; the hand-rolled `pagy_metadata` helper builds
  `{ current_page:, total_pages:, total_count:, per_page: }` from `pagy.page`,
  `pagy.pages`, `pagy.count`, `pagy.limit`.
- `app/controllers/api/v1/recipes_controller.rb` (`#index`, `#search`),
  `app/controllers/api/v1/categories_controller.rb` (`#show`),
  `app/controllers/api/v1/meal_plans_controller.rb` (`#index`) - each `pagy(scope)`
  call becomes `pagy(:offset, scope)`.
- Any HTML pagination added later (recipes index) - the frontend helpers changed too.

## Guardrails

`spec/requests/api/v1/pagination_spec.rb` asserts the exact JSON pagination payload
(`current_page`, `total_pages`, `total_count`, `per_page`) for the recipes index,
recipe search, category show, and meal plan index, plus the configured defaults
(limit 20, overflow `:last_page`). A future major bump that silently reshapes the
payload will fail there instead of shipping.

## Known gaps (unchanged by this pin)

- The Swagger docs advertise a `limit` query parameter on `GET /api/v1/recipes`, but
  page size is not actually caller-configurable: that requires
  `require "pagy/extras/limit"`, which we do not load. Page size is fixed at 20.
- `config/initializers/pagy.rb` previously set `Pagy::DEFAULT[:items]`, which pagy 9
  ignores entirely (the option was renamed to `:limit` in pagy 9.0). It happened to be
  harmless because 20 is also pagy's built-in default; it is now set as `:limit`.

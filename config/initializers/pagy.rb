# frozen_string_literal: true

# Pinned to pagy 9.x — see UPGRADE_NOTES.md for the v43 migration path.
# In pagy 9 the page-size option is :limit (it was :items in pagy 8 and earlier);
# setting :items here would be silently ignored.
require "pagy/extras/metadata"
require "pagy/extras/overflow"

Pagy::DEFAULT[:limit] = 20
Pagy::DEFAULT[:overflow] = :last_page

# Items per page for the HTML recipes list (index + search).
#
# Kept separate from Pagy::DEFAULT so the JSON API keeps its own page size:
# 12 is a clean multiple of the 1/2/3-column Tailwind grid used by the recipe
# cards, whereas the API is happier with larger pages.
Rails.application.config.x.recipes_per_page = Integer(ENV.fetch("RECIPES_PER_PAGE", 12))

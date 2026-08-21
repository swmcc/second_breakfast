# frozen_string_literal: true

# Pinned to pagy 9.x — see UPGRADE_NOTES.md for the v43 migration path.
# In pagy 9 the page-size option is :limit (it was :items in pagy 8 and earlier);
# setting :items here would be silently ignored.
require "pagy/extras/metadata"
require "pagy/extras/overflow"

Pagy::DEFAULT[:limit] = 20
Pagy::DEFAULT[:overflow] = :last_page

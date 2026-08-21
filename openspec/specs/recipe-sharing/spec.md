# Recipe Sharing and Social Specification

## Overview

Covers recipe ownership, public/private visibility, shareable links, the
print-friendly view, ratings, reviews and favorites.

This capability amends **REQ-RCP-020 (Public Viewing)** in
`openspec/specs/recipes/spec.md`: unauthenticated viewing now applies to
*public* recipes rather than to every recipe.

## Requirements

### Ownership and Visibility

#### REQ-SHR-001: Recipe Ownership
A Recipe MAY have an owner (`user_id`, nullable).
- Recipes created through the web UI or the API MUST record the acting user as owner.
- Recipes that predate ownership have no owner and MUST keep working.
- When an owner deletes their account, their recipes MUST survive with `user_id` nullified.

#### REQ-SHR-002: Visibility Flag
A Recipe MUST have a `visibility` of either `public` or `private`.
- The column defaults to `public`, preserving the previous world-readable behaviour.
- Only the owner (or any signed-in user, for an unowned legacy recipe) MAY change it.

#### REQ-SHR-003: Read Authorization
- A `public` recipe SHALL be readable by anyone, signed in or not.
- A `private` recipe SHALL be readable only by its owner.
- Authorization MUST be enforced in the controller layer via `Recipe.visible_to(user)`,
  not by hiding elements in views.
- Recipe index, search, show, print and every API recipe endpoint MUST apply it.
- A recipe the current user may not read MUST respond `404 Not Found`, not `403`,
  so the existence of a private recipe is not disclosed.

### Sharing

#### REQ-SHR-010: Share Token
Every Recipe MUST have a unique, non-guessable `public_token` (24+ characters),
generated on create and backfilled for pre-existing recipes.

#### REQ-SHR-011: Share Link
`GET /r/:token` SHALL render a read-only recipe page.
- It MUST work while signed out.
- It is a capability link: it grants read access even to a `private` recipe.
  This is deliberate — it is what "share this recipe" means — and the UI warns
  the owner of a private recipe accordingly.
- An unknown token MUST respond `404 Not Found`.

#### REQ-SHR-012: Copy Share Link
The recipe page SHALL offer the share URL as selectable text plus a
"Copy share link" control backed by the browser clipboard API, degrading to a
plain readonly input when the clipboard API is unavailable.

#### REQ-SHR-013: Social Sharing
The recipe page SHALL offer share links for X, Facebook, Bluesky, WhatsApp and
email as plain URLs. No third-party SDK or script MAY be loaded — the app's CSP
allows `script-src :self` only.

#### REQ-SHR-014: Open Graph Metadata
A `public` recipe page MUST emit `og:type`, `og:site_name`, `og:title`,
`og:description`, `og:url`, `og:image` (when an image is attached), and the
matching `twitter:card` tags.
A `private` recipe page MUST instead emit `robots: noindex, nofollow` and no
Open Graph tags.

### Print

#### REQ-SHR-020: Print View
`GET /recipes/:id/print` and `GET /r/:token/print` SHALL render the recipe using
a dedicated print layout.
- The layout MUST omit site navigation, the search bar and the footer.
- The view MUST show title, description, serves, prep time, category,
  ingredients with quantities and units, instructions and nutrition.
- Screen-only controls MUST be hidden with Tailwind `print:` utilities.
- The print view MUST honour the same read authorization as the recipe page.

### Ratings

#### REQ-SHR-030: Rating Model
A Rating belongs to a User and a Recipe and has an integer `value` from 1 to 5.
- A user MAY hold at most one rating per recipe, enforced by a unique index.
- Posting a rating again MUST update the existing one rather than add another.

#### REQ-SHR-031: Rating Authorization
Only signed-in users MAY rate, and only recipes they are allowed to read.
Removing a rating MUST only remove the current user's own rating.

#### REQ-SHR-032: Average Rating
The recipe page SHALL display the average rating to one decimal place and the
number of ratings, or "No ratings yet."

### Reviews

#### REQ-SHR-040: Review Model
A Review belongs to a User and a Recipe and has a required `body` of at most
2000 characters. A user MAY leave more than one review on a recipe.

#### REQ-SHR-041: Review Authorization
Only signed-in users MAY post reviews, and only on recipes they are allowed to
read. Only the review's author MAY edit or delete it; anyone else MUST get
`404 Not Found`.

#### REQ-SHR-042: Review Display
Reviews SHALL be listed on the recipe page newest first, with the author and
timestamp. Edit and delete controls SHALL appear only for the author.

### Favorites

#### REQ-SHR-050: Favorite Model
A Favorite belongs to a User and a Recipe, unique per pair.

#### REQ-SHR-051: Distinct From Basket
Favorites MUST NOT affect the Basket, the aggregated shopping list or meal
plans. A Basket entry is a shopping selection; a Favorite is a bookmark.

#### REQ-SHR-052: Favorites List
`GET /favorites` SHALL list the current user's favorites, newest first, and MUST
omit any recipe that is no longer readable by them.

## Scenarios

### Scenario: Signed-out visitor opens a private recipe

**Given** a recipe with visibility "private" owned by another user
**When** a signed-out visitor requests `/recipes/:id`
**Then** the response SHALL be `404 Not Found`

### Scenario: Owner shares a private recipe

**Given** a private recipe owned by the signed-in user
**When** the owner copies the share link and sends it to a friend
**Then** the friend SHALL be able to read the recipe at `/r/:token` without signing in
**And** the page SHALL carry `robots: noindex, nofollow`

### Scenario: Rating a recipe twice

**Given** a signed-in user who has already rated a recipe 2 stars
**When** the user submits a 5 star rating
**Then** the recipe SHALL have exactly one rating from that user, worth 5

### Scenario: Editing someone else's review

**Given** a review written by another user
**When** a signed-in user requests its edit page
**Then** the response SHALL be `404 Not Found`

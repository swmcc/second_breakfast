# Meal Planning Specification

## Overview

The Meal Planning domain covers the basket functionality, allowing users to select recipes for their meal plan and generate aggregated shopping lists. This is a core feature that differentiates Second Breakfast from a simple recipe browser.

## Requirements

### Basket Data Model

#### REQ-MPL-001: Basket Attributes
A Basket entity MUST have the following attributes:
- `user_id` (foreign key, required) - Reference to the owning User
- `recipe_id` (foreign key, required) - Reference to the selected Recipe

#### REQ-MPL-002: Basket Uniqueness
A user SHALL NOT be able to add the same recipe to their basket twice.
- The combination of `user_id` and `recipe_id` MUST be unique

#### REQ-MPL-003: Cascade Deletion
When a User is deleted, all associated Basket entries MUST be deleted.
When a Recipe is deleted, all associated Basket entries MUST be deleted.

### Basket Operations

#### REQ-MPL-010: Add to Basket
Authenticated users SHALL be able to add recipes to their basket.
- The system MUST create a Basket record linking User and Recipe
- The user SHALL receive a success notification

#### REQ-MPL-011: Remove from Basket
Authenticated users SHALL be able to remove recipes from their basket.
- The system MUST delete the corresponding Basket record
- The user SHALL receive a success notification

#### REQ-MPL-012: Toggle Basket
The toggle action MUST:
- Add the recipe if not in basket
- Remove the recipe if already in basket
- Redirect back to recipes index

#### REQ-MPL-013: Authentication Required
All basket operations MUST require authentication.
- Unauthenticated users SHALL be redirected to sign in

### Basket Viewing

#### REQ-MPL-020: Chosen Meals Page
The "Chosen Meals" page SHALL display:
- All recipes in the current user's basket
- Recipe image (if available) or placeholder
- Recipe title
- Recipe description

#### REQ-MPL-021: Empty Basket State
When the basket is empty:
- A message SHALL indicate no meals are selected
- A link to browse recipes SHALL be displayed

### Shopping List Generation

#### REQ-MPL-030: Aggregated Ingredients
The shopping list MUST aggregate ingredients across all basket recipes.
- Ingredients with the same name AND unit SHALL be combined
- Quantities SHALL be summed

#### REQ-MPL-031: Ingredient Display
Each shopping list item SHALL display:
- Ingredient name (capitalized)
- Total quantity
- Unit of measurement

#### REQ-MPL-032: Shopping List Visibility
The shopping list SHALL only be displayed when the basket contains recipes.

### Basket Status in Recipe List

#### REQ-MPL-040: Basket Status Helper
The User model MUST provide an `in_basket?(recipe)` method that:
- Returns true if the recipe is in the user's basket
- Returns false if the recipe is not in the user's basket

#### REQ-MPL-041: Visual Basket Indicator
On the recipes index page:
- Recipes in the basket SHALL show "Chosen"
- Recipes not in the basket SHALL show "Choose"

### Recipe-User Relationship

#### REQ-MPL-050: User-Recipe Through Basket
The User model SHALL have:
- `has_many :baskets`
- `has_many :recipes, through: :baskets`

#### REQ-MPL-051: Recipe-User Through Basket
The Recipe model SHALL have:
- `has_many :baskets`
- `has_many :users, through: :baskets`

## Scenarios

### Scenario: Add Recipe to Empty Basket

**Given** a user is logged in
**And** the user's basket is empty
**When** the user clicks "Choose" on a recipe
**Then** the recipe SHALL be added to the basket
**And** "Recipe added to your basket!" SHALL be displayed
**And** the button SHALL change to "Chosen"

### Scenario: Remove Recipe from Basket

**Given** a user is logged in
**And** the user has "Chicken Curry" in their basket
**When** the user clicks "Chosen" on "Chicken Curry"
**Then** the recipe SHALL be removed from the basket
**And** "Recipe removed from your basket!" SHALL be displayed
**And** the button SHALL change to "Choose"

### Scenario: Attempt to Add Duplicate Recipe

**Given** a user is logged in
**And** the user already has "Pasta" in their basket
**When** the user attempts to add "Pasta" again via direct request
**Then** the basket SHALL NOT contain duplicate entries
**And** the uniqueness validation SHALL prevent the duplicate

### Scenario: View Chosen Meals

**Given** a user is logged in
**And** the user has 3 recipes in their basket
**When** the user visits the "Chosen Meals" page
**Then** all 3 recipes SHALL be displayed
**And** each recipe SHALL show its title and description
**And** images SHALL be displayed for recipes that have them

### Scenario: View Empty Basket

**Given** a user is logged in
**And** the user's basket is empty
**When** the user visits the "Chosen Meals" page
**Then** "No meals in your basket" SHALL be displayed
**And** a "Browse Recipes" link SHALL be displayed
**And** the shopping list SHALL NOT be displayed

### Scenario: Generate Shopping List

**Given** a user is logged in
**And** the user has recipes in their basket with these ingredients:
- Recipe 1: eggs (4 large), flour (200 grams)
- Recipe 2: eggs (2 large), milk (300 ml)
**When** the user views the "Chosen Meals" page
**Then** the shopping list SHALL show:
- Eggs: 6 large
- Flour: 200 grams
- Milk: 300 ml

### Scenario: Shopping List with Same Ingredient Different Units

**Given** a user is logged in
**And** recipes in basket have:
- Recipe 1: butter (2 tbsp)
- Recipe 2: butter (50 grams)
**When** the user views the shopping list
**Then** butter SHALL appear as two separate entries:
- Butter: 2 tbsp
- Butter: 50 grams

### Scenario: Unauthenticated User Attempts Basket Action

**Given** a visitor is not logged in
**When** the visitor attempts to toggle a recipe in basket
**Then** the visitor SHALL be redirected to sign in
**And** "You must sign in first" SHALL be displayed

### Scenario: Recipe Not Found

**Given** a user is logged in
**When** the user attempts to toggle a non-existent recipe (invalid ID)
**Then** "Recipe not found" SHALL be displayed
**And** the user SHALL be redirected to the recipes page

### Scenario: Delete User with Basket Items

**Given** a user has recipes in their basket
**When** the user account is deleted
**Then** all associated basket entries SHALL be deleted
**And** the recipes themselves SHALL remain in the system

### Scenario: Delete Recipe in User Baskets

**Given** a recipe is in multiple users' baskets
**When** the recipe is deleted
**Then** all basket entries for that recipe SHALL be deleted
**And** the users' other basket items SHALL remain intact

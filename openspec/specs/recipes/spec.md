# Recipe Management Specification

## Overview

The Recipe domain covers the creation, viewing, searching, and management of recipes in the Second Breakfast application. Recipes are the core entity around which meal planning revolves.

## Requirements

### Recipe Data Model

#### REQ-RCP-001: Recipe Attributes
A Recipe entity MUST have the following required attributes:
- `title` (string) - The name of the recipe
- `description` (text) - A brief description of the recipe
- `serves` (integer) - Number of servings
- `prep_time` (string) - Preparation time (e.g., "30 minutes")
- `instructions` (rich text) - Step-by-step cooking instructions
- `ingredients` (JSON array) - List of ingredients with quantities
- `nutrition` (JSON object) - Nutritional information
- `category_id` (foreign key) - Reference to Category

#### REQ-RCP-002: Ingredient Structure
Each ingredient in the `ingredients` array MUST contain:
- `name` (string) - Ingredient name
- `quantity` (numeric) - Amount required
- `unit` (string) - Unit of measurement

#### REQ-RCP-003: Nutrition Structure
The `nutrition` object MUST contain all of the following fields:
- `calories` - Energy content
- `protein` - Protein content
- `fat` - Fat content
- `carbs` - Carbohydrate content
- `fibre` - Fibre content
- `sugar` - Sugar content
- `sodium` - Sodium content

#### REQ-RCP-004: Recipe Images
A Recipe MAY have an attached image via Active Storage.
- Images SHOULD be displayed with appropriate variants for performance
- Thumbnail variant SHALL use `resize_to_limit: [200, 200]`

### Recipe Validation

#### REQ-RCP-010: Required Field Validation
The system MUST validate presence of:
- title
- description
- serves
- prep_time
- instructions
- ingredients
- nutrition

#### REQ-RCP-011: Nutrition Format Validation
The system MUST reject recipes where nutrition is missing any required field.

### Recipe CRUD Operations

#### REQ-RCP-020: Public Viewing
- All users (authenticated or not) SHALL be able to view the recipe list
- All users SHALL be able to view individual recipe details
- All users SHALL be able to search recipes

#### REQ-RCP-021: Authenticated Creation
- Only authenticated users SHALL be able to create new recipes
- The system MUST redirect unauthenticated users to sign in

#### REQ-RCP-022: Authenticated Editing
- Only authenticated users SHALL be able to edit existing recipes
- The system MUST redirect unauthenticated users to sign in

#### REQ-RCP-023: Authenticated Deletion
- Only authenticated users SHALL be able to delete recipes
- Deletion MUST remove associated basket entries

### Recipe Search

#### REQ-RCP-030: Search by Title
The search function MUST find recipes where the title contains the search query (case-insensitive).

#### REQ-RCP-031: Search by Ingredient
The search function MUST find recipes where any ingredient name contains the search query (case-insensitive).

#### REQ-RCP-032: Empty Search
When no query is provided, the search SHALL return an empty result set.

### Recipe Homepage

#### REQ-RCP-040: Random Recipe Display
The homepage SHALL display a randomly selected recipe.

## Scenarios

### Scenario: Create a New Recipe

**Given** a user is authenticated
**When** the user submits the new recipe form with:
- Title: "Scrambled Eggs"
- Description: "Quick and easy breakfast"
- Serves: 2
- Prep time: "10 minutes"
- Instructions: "Beat eggs, cook in pan..."
- Ingredients: [{ name: "eggs", quantity: 4, unit: "large" }]
- Nutrition: { calories: 200, protein: 14, fat: 15, carbs: 2, fibre: 0, sugar: 1, sodium: 300 }
**Then** the recipe SHALL be created successfully
**And** the user SHALL be redirected to the recipe show page
**And** a success notice SHALL be displayed

### Scenario: Create Recipe with Missing Fields

**Given** a user is authenticated
**When** the user submits the new recipe form without a title
**Then** the recipe SHALL NOT be created
**And** the form SHALL be re-rendered with errors
**And** validation errors SHALL be displayed

### Scenario: Search Recipes by Title

**Given** recipes exist with titles "Chicken Curry" and "Chicken Salad"
**When** a user searches for "chicken"
**Then** both "Chicken Curry" and "Chicken Salad" SHALL appear in results

### Scenario: Search Recipes by Ingredient

**Given** a recipe exists with ingredient "garlic"
**When** a user searches for "garlic"
**Then** the recipe SHALL appear in search results

### Scenario: Unauthenticated User Creates Recipe

**Given** a user is NOT authenticated
**When** the user attempts to access the new recipe page
**Then** the user SHALL be redirected to the sign-in page
**And** an alert message SHALL be displayed

### Scenario: Delete Recipe with Basket Entries

**Given** a recipe exists in multiple users' baskets
**When** an authenticated user deletes the recipe
**Then** the recipe SHALL be deleted
**And** all associated basket entries SHALL be removed
**And** no orphaned basket records SHALL remain

### Scenario: View Random Recipe on Homepage

**Given** multiple recipes exist in the database
**When** a user visits the homepage
**Then** a single recipe SHALL be displayed
**And** the recipe MAY differ on page refresh

### Scenario: Recipe with Image

**Given** a user is creating a recipe
**When** the user attaches a valid image file
**Then** the image SHALL be stored via Active Storage
**And** the image SHALL be displayed on the recipe show page
**And** a thumbnail variant SHALL be displayed on the index page

# Second Breakfast MCP Server

An MCP (Model Context Protocol) server that enables Claude to manage recipes in Second Breakfast. Combined with Claude's vision capabilities, this allows rapid recipe import from photos of recipe books.

## Installation

```bash
cd mcp-server
npm install
```

## Configuration

The server requires two environment variables:

| Variable | Description | Default |
|----------|-------------|---------|
| `API_URL` | Second Breakfast API base URL | `http://localhost:3000/api/v1` |
| `API_TOKEN` | Your API key | (required) |

**Every** operation — including reads and search — requires the key; the server exits at startup if `API_TOKEN` is missing.

### Getting an API Key

1. Sign in to Second Breakfast and open **Account** (`/account`)
2. In the **API Keys** section, give the key a name (e.g. "MCP server") and click **Create key**
3. Copy the `sb_...` token — it is shown **exactly once** and cannot be retrieved again

Keys can be revoked from the same page at any time.

## Usage with Claude Desktop

Add to your `~/Library/Application Support/Claude/claude_desktop_config.json`:

```json
{
  "mcpServers": {
    "second-breakfast": {
      "command": "node",
      "args": ["/path/to/second_breakfast/mcp-server/index.js"],
      "env": {
        "API_URL": "http://localhost:3000/api/v1",
        "API_TOKEN": "your-token-here"
      }
    }
  }
}
```

## Usage with Claude Code

Add to your project's `.mcp.json`:

```json
{
  "mcpServers": {
    "second-breakfast": {
      "command": "node",
      "args": ["./mcp-server/index.js"],
      "env": {
        "API_TOKEN": "your-token-here"
      }
    }
  }
}
```

## Available Tools

### `list_categories`

List all available recipe categories.

**Example prompt:** "What categories are available for recipes?"

### `search_recipes`

Search for existing recipes by title or description.

**Parameters:**
- `query` (string) - Search term

**Example prompt:** "Search for chocolate cake recipes"

### `get_recipe`

Get full details of a recipe by ID.

**Parameters:**
- `id` (number) - Recipe ID

**Example prompt:** "Show me recipe #42"

### `create_recipe`

Create a new recipe with all fields. An image is automatically fetched in the background based on the recipe title.

**Parameters:**
- `title` (string) - Recipe title
- `description` (string) - Brief description
- `serves` (number) - Number of servings
- `prep_time` (string) - e.g., "30 minutes"
- `category_id` (number) - Category ID
- `instructions` (string) - Cooking instructions
- `ingredients` (array) - List of {name, quantity, unit}
- `nutrition` (object) - {calories, protein, fat, carbs, fibre, sugar, sodium}
- `image_data` (string, optional) - Base64-encoded image data URL
- `fetch_image` (boolean, optional) - Auto-fetch image (default: true)

**Note:** Recipe creation returns immediately. The image is fetched asynchronously by a background job and will appear shortly after.

### Meal plan tools

Weekly meal plans run Monday–Sunday, one plan per week. Draft plans are editable; accepting locks a plan (reopen until the week ends); past weeks are read-only archive.

- `list_meal_plans` — list plans, newest first (`filter`: `active` / `archived`)
- `get_meal_plan` — a plan's full Monday–Sunday grid (`id`)
- `create_meal_plan` — plan a week (`week_start_date` optional; defaults to the current week, any date normalises to Monday; past weeks rejected)
- `add_meal_to_plan` — add a recipe to a day (`plan_id`, `recipe_id`, `day`)
- `remove_meal_from_plan` — remove an entry (`plan_id`, `entry_id`)
- `accept_meal_plan` / `reopen_meal_plan` — lock / unlock a plan (`id`)
- `get_meal_plan_shopping_list` — aggregated ingredients for the week (`id`)

**Example prompt:**
```
Plan next week for me: use my existing recipes, fish twice,
no beef, and keep breakfasts quick. Then show me the shopping list.
```

## Example Workflows

### Import Recipe from Photo

1. Take a photo of a recipe page
2. Send to Claude: "Create a recipe from this photo"
3. Claude extracts the data and calls `create_recipe`

**Example prompt:**
```
Here's a photo of my grandmother's apple pie recipe.
Please extract all the details and create it in Second Breakfast.
```

### Batch Import

```
I'm going to show you 5 recipe photos from my cookbook.
For each one, please:
1. Extract the recipe details
2. Check if we already have it (search_recipes)
3. If not, create it (create_recipe)
```

### Check Before Import

```
I want to add this chocolate cake recipe. First check if we
already have a similar one, and only create it if we don't.
```

## Troubleshooting

### "Unauthorized" error

- Check that `API_TOKEN` is set correctly
- Check the key hasn't been revoked on the Account page (`/account`, API Keys section) — if it has, create a new one there

### Server not connecting

- Ensure the Second Breakfast Rails server is running (`bin/dev`)
- Check the `API_URL` is correct
- Verify the MCP server path in your config

### Recipe creation fails

- Check all required fields are provided
- Verify the `category_id` exists (use `list_categories`)
- Check the Rails logs for validation errors

#!/usr/bin/env node

import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { z } from "zod";

const API_URL = process.env.API_URL || "http://localhost:3000/api/v1";
const API_TOKEN = process.env.API_TOKEN || "";

if (!API_TOKEN) {
  console.error(
    "API_TOKEN is required — every API operation needs it. " +
    "Create an API key in Second Breakfast under Account -> API Keys (/account)."
  );
  process.exit(1);
}

async function apiRequest(method, path, body = null) {
  const url = `${API_URL}${path}`;
  const headers = {
    "Content-Type": "application/json",
    "Accept": "application/json",
    "Authorization": `Bearer ${API_TOKEN}`,
  };

  const options = { method, headers };
  if (body) {
    options.body = JSON.stringify(body);
  }

  const response = await fetch(url, options);
  const data = await response.json();

  if (response.status === 401) {
    throw new Error(
      "API key invalid or revoked — create a new one in Second Breakfast under Account -> API Keys (/account)."
    );
  }

  if (!response.ok) {
    throw new Error(data.error || data.errors?.join(", ") || "API request failed");
  }

  return data;
}

const server = new McpServer({
  name: "second-breakfast",
  version: "1.0.0",
});

// List categories tool
server.tool(
  "list_categories",
  "List all available recipe categories",
  {},
  async () => {
    const data = await apiRequest("GET", "/categories");
    return {
      content: [
        {
          type: "text",
          text: JSON.stringify(data.categories, null, 2),
        },
      ],
    };
  }
);

// Search recipes tool
server.tool(
  "search_recipes",
  "Search for existing recipes by title or description",
  {
    query: z.string().describe("Search query to find recipes"),
  },
  async ({ query }) => {
    const data = await apiRequest("GET", `/recipes/search?query=${encodeURIComponent(query)}`);
    return {
      content: [
        {
          type: "text",
          text: JSON.stringify(data, null, 2),
        },
      ],
    };
  }
);

// Get recipe tool
server.tool(
  "get_recipe",
  "Get full details of a recipe by ID",
  {
    id: z.number().describe("Recipe ID"),
  },
  async ({ id }) => {
    const data = await apiRequest("GET", `/recipes/${id}`);
    return {
      content: [
        {
          type: "text",
          text: JSON.stringify(data, null, 2),
        },
      ],
    };
  }
);

// Create recipe tool
server.tool(
  "create_recipe",
  "Create a new recipe in Second Breakfast. IMPORTANT: For ingredients, put ONLY the ingredient name in 'name' (e.g., 'bell peppers' not 'bell peppers, halved'). Put prep instructions like 'halved', 'chopped', 'minced' in the main instructions field instead. Use standard units only (g, kg, ml, l, cups, tbsp, tsp, whole, pinch).",
  {
    title: z.string().describe("Recipe title"),
    description: z.string().describe("Brief description of the recipe"),
    serves: z.number().describe("Number of servings"),
    prep_time: z.string().describe("Preparation time (e.g., '30 minutes')"),
    category_id: z.number().describe("Category ID (use list_categories to find)"),
    instructions: z.string().describe("Step-by-step cooking instructions. Include ingredient prep details here (e.g., 'Dice the onion, mince the garlic...')"),
    ingredients: z
      .array(
        z.object({
          name: z.string().describe("Ingredient name ONLY - no prep instructions (e.g., 'onion' not 'onion, diced')"),
          quantity: z.string().describe("Numeric amount (e.g., '2', '100', '0.5')"),
          unit: z.string().describe("Standard unit ONLY: g, kg, ml, l, cups, tbsp, tsp, whole, pinch, to taste"),
        })
      )
      .describe("List of ingredients with simple names and standard units"),
    nutrition: z
      .object({
        calories: z.string().describe("Calories per serving - NUMBER ONLY, no units (e.g., '250' not '250 kcal')"),
        protein: z.string().describe("Protein grams - NUMBER ONLY (e.g., '10' not '10g')"),
        fat: z.string().describe("Fat grams - NUMBER ONLY (e.g., '5' not '5g')"),
        carbs: z.string().describe("Carbs grams - NUMBER ONLY (e.g., '30' not '30g')"),
        fibre: z.string().describe("Fibre grams - NUMBER ONLY (e.g., '3' not '3g')"),
        sugar: z.string().describe("Sugar grams - NUMBER ONLY (e.g., '5' not '5g')"),
        sodium: z.string().describe("Sodium milligrams - NUMBER ONLY (e.g., '200' not '200mg')"),
      })
      .describe("Nutritional information per serving - ALL VALUES MUST BE NUMBERS ONLY without units"),
    image_data: z
      .string()
      .optional()
      .describe("Optional base64-encoded image data URL. If not provided, an image will be fetched automatically in the background."),
    fetch_image: z
      .boolean()
      .optional()
      .default(true)
      .describe("Auto-fetch an image in the background. Defaults to true. Set to false to skip."),
  },
  async ({ title, description, serves, prep_time, category_id, instructions, ingredients, nutrition, image_data, fetch_image }) => {
    const recipeData = {
      title,
      description,
      serves,
      prep_time,
      category_id,
      instructions,
      ingredients,
      nutrition,
      fetch_image: fetch_image !== false,
    };

    if (image_data) {
      recipeData.image_data = image_data;
    }

    const recipe = { recipe: recipeData };
    const data = await apiRequest("POST", "/recipes", recipe);

    const imageNote = !image_data && fetch_image !== false
      ? " An image will be fetched in the background."
      : "";

    return {
      content: [
        {
          type: "text",
          text: `Recipe "${data.title}" created successfully with ID ${data.id}.${imageNote}\n\n${JSON.stringify(data, null, 2)}`,
        },
      ],
    };
  }
);

// Meal plan tools.
// Rules: weeks run Monday-Sunday and one plan exists per week. Only draft
// plans are editable; accepting locks a plan and reopening is possible until
// the week ends. Past weeks are read-only archive.

const DAY_ENUM = z.enum(["monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday"]);

server.tool(
  "list_meal_plans",
  "List the user's weekly meal plans, newest first. Each week runs Monday-Sunday and a user can only have one plan per week.",
  {
    filter: z.enum(["active", "archived"]).optional().describe("Optional filter: 'active' for current/future weeks, 'archived' for past weeks"),
  },
  async ({ filter }) => {
    const qs = filter ? `?filter=${filter}` : "";
    const data = await apiRequest("GET", `/meal_plans${qs}`);
    return {
      content: [{ type: "text", text: JSON.stringify(data, null, 2) }],
    };
  }
);

server.tool(
  "get_meal_plan",
  "Get a meal plan's full Monday-Sunday grid with the recipes planned for each day.",
  {
    id: z.number().describe("Meal plan ID (use list_meal_plans to find)"),
  },
  async ({ id }) => {
    const data = await apiRequest("GET", `/meal_plans/${id}`);
    return {
      content: [{ type: "text", text: JSON.stringify(data, null, 2) }],
    };
  }
);

server.tool(
  "create_meal_plan",
  "Create a meal plan for a week. Defaults to the current week; pass any date inside a future week to plan ahead (it normalises to that week's Monday). Only one plan can exist per week - if one already exists the error includes it. Past weeks cannot be planned.",
  {
    week_start_date: z
      .string()
      .optional()
      .describe("Optional date (YYYY-MM-DD) inside the target week. Omit for the current week."),
    auto_fill: z
      .boolean()
      .optional()
      .describe("If true, automatically fills the week with one breakfast, one lunch and one dinner per day, picked from the user's recipes by category."),
  },
  async ({ week_start_date, auto_fill }) => {
    const body = { meal_plan: {} };
    if (week_start_date) body.meal_plan.week_start_date = week_start_date;
    if (auto_fill) body.meal_plan.auto_fill = true;
    const data = await apiRequest("POST", "/meal_plans", body);
    return {
      content: [{ type: "text", text: `Meal plan created for week beginning ${data.week_start_date}.\n\n${JSON.stringify(data, null, 2)}` }],
    };
  }
);

server.tool(
  "add_meal_to_plan",
  "Add a recipe to a day of a draft meal plan. The same recipe cannot be added twice to one day. Fails if the plan is accepted (reopen it first) or archived.",
  {
    plan_id: z.number().describe("Meal plan ID"),
    recipe_id: z.number().describe("Recipe ID (use search_recipes to find)"),
    day: DAY_ENUM.describe("Day of the week"),
  },
  async ({ plan_id, recipe_id, day }) => {
    const data = await apiRequest("POST", `/meal_plans/${plan_id}/entries`, { entry: { recipe_id, day } });
    return {
      content: [{ type: "text", text: `Added "${data.recipe.title}" to ${data.day}.\n\n${JSON.stringify(data, null, 2)}` }],
    };
  }
);

server.tool(
  "remove_meal_from_plan",
  "Remove an entry from a draft meal plan (entry_id comes from get_meal_plan). Fails if the plan is accepted (reopen it first) or archived.",
  {
    plan_id: z.number().describe("Meal plan ID"),
    entry_id: z.number().describe("Entry ID to remove"),
  },
  async ({ plan_id, entry_id }) => {
    await apiRequest("DELETE", `/meal_plans/${plan_id}/entries/${entry_id}`);
    return {
      content: [{ type: "text", text: `Entry ${entry_id} removed from meal plan ${plan_id}.` }],
    };
  }
);

server.tool(
  "accept_meal_plan",
  "Accept a draft meal plan, locking it against changes. It can be reopened until its week ends.",
  {
    id: z.number().describe("Meal plan ID"),
  },
  async ({ id }) => {
    const data = await apiRequest("POST", `/meal_plans/${id}/accept`);
    return {
      content: [{ type: "text", text: `Meal plan for week beginning ${data.week_start_date} accepted and locked.\n\n${JSON.stringify(data, null, 2)}` }],
    };
  }
);

server.tool(
  "reopen_meal_plan",
  "Reopen an accepted meal plan so it can be edited again. Only works while the plan's week has not ended.",
  {
    id: z.number().describe("Meal plan ID"),
  },
  async ({ id }) => {
    const data = await apiRequest("POST", `/meal_plans/${id}/reopen`);
    return {
      content: [{ type: "text", text: `Meal plan for week beginning ${data.week_start_date} reopened for editing.\n\n${JSON.stringify(data, null, 2)}` }],
    };
  }
);

server.tool(
  "get_meal_plan_shopping_list",
  "Get the aggregated shopping list for a meal plan - every ingredient across the week's recipes, summed by name and unit.",
  {
    id: z.number().describe("Meal plan ID"),
  },
  async ({ id }) => {
    const data = await apiRequest("GET", `/meal_plans/${id}/shopping_list`);
    return {
      content: [{ type: "text", text: JSON.stringify(data, null, 2) }],
    };
  }
);

// Start the server
async function main() {
  const transport = new StdioServerTransport();
  await server.connect(transport);
  console.error("Second Breakfast MCP server running");
}

main().catch(console.error);

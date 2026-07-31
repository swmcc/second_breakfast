#!/usr/bin/env node

import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { z } from "zod";

const API_URL = process.env.API_URL || "http://localhost:3000/api/v1";
const API_TOKEN = process.env.API_TOKEN || "";

async function apiRequest(method, path, body = null) {
  const url = `${API_URL}${path}`;
  const headers = {
    "Content-Type": "application/json",
    "Accept": "application/json",
  };

  if (API_TOKEN) {
    headers["Authorization"] = `Bearer ${API_TOKEN}`;
  }

  const options = { method, headers };
  if (body) {
    options.body = JSON.stringify(body);
  }

  const response = await fetch(url, options);
  const data = await response.json();

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
  "Create a new recipe in Second Breakfast",
  {
    title: z.string().describe("Recipe title"),
    description: z.string().describe("Brief description of the recipe"),
    serves: z.number().describe("Number of servings"),
    prep_time: z.string().describe("Preparation time (e.g., '30 minutes')"),
    category_id: z.number().describe("Category ID (use list_categories to find)"),
    instructions: z.string().describe("Step-by-step cooking instructions"),
    ingredients: z
      .array(
        z.object({
          name: z.string().describe("Ingredient name"),
          quantity: z.string().describe("Amount needed"),
          unit: z.string().describe("Unit of measurement (cups, tbsp, g, etc.)"),
        })
      )
      .describe("List of ingredients"),
    nutrition: z
      .object({
        calories: z.string().describe("Calories per serving"),
        protein: z.string().describe("Protein per serving (e.g., '10g')"),
        fat: z.string().describe("Fat per serving (e.g., '5g')"),
        carbs: z.string().describe("Carbohydrates per serving (e.g., '30g')"),
        fibre: z.string().describe("Fibre per serving (e.g., '3g')"),
        sugar: z.string().describe("Sugar per serving (e.g., '5g')"),
        sodium: z.string().describe("Sodium per serving (e.g., '200mg')"),
      })
      .describe("Nutritional information per serving"),
  },
  async ({ title, description, serves, prep_time, category_id, instructions, ingredients, nutrition }) => {
    const recipe = {
      recipe: {
        title,
        description,
        serves,
        prep_time,
        category_id,
        instructions,
        ingredients,
        nutrition,
      },
    };

    const data = await apiRequest("POST", "/recipes", recipe);
    return {
      content: [
        {
          type: "text",
          text: `Recipe "${data.title}" created successfully with ID ${data.id}.\n\n${JSON.stringify(data, null, 2)}`,
        },
      ],
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

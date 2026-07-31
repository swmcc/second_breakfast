#!/usr/bin/env node

import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { z } from "zod";

const API_URL = process.env.API_URL || "http://localhost:3000/api/v1";
const API_TOKEN = process.env.API_TOKEN || "";

async function fetchGoogleImage(query) {
  try {
    const searchQuery = encodeURIComponent(query + " recipe food");
    const url = `https://www.google.com/search?q=${searchQuery}&tbm=isch&safe=active`;

    const response = await fetch(url, {
      headers: {
        "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
        "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8",
        "Accept-Language": "en-US,en;q=0.5",
      },
    });

    if (!response.ok) {
      console.error("Google search failed:", response.status);
      return null;
    }

    const html = await response.text();

    // Extract image URLs from the page - Google embeds them in data attributes and scripts
    const imgRegex = /\["(https:\/\/[^"]+\.(?:jpg|jpeg|png|webp))",\d+,\d+\]/gi;
    const matches = [...html.matchAll(imgRegex)];

    if (matches.length === 0) {
      // Try alternate pattern
      const altRegex = /"ou":"(https:\/\/[^"]+)"/gi;
      const altMatches = [...html.matchAll(altRegex)];
      if (altMatches.length === 0) {
        console.error("No images found in Google results");
        return null;
      }
      matches.push(...altMatches);
    }

    // Get a decent sized image (skip tiny thumbnails)
    const imageUrl = matches[0][1];
    console.error("Fetching image:", imageUrl);

    const imageResponse = await fetch(imageUrl, {
      headers: {
        "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36",
        "Referer": "https://www.google.com/",
      },
    });

    if (!imageResponse.ok) {
      console.error("Failed to fetch image:", imageResponse.status);
      return null;
    }

    const contentType = imageResponse.headers.get("content-type") || "image/jpeg";
    const arrayBuffer = await imageResponse.arrayBuffer();
    const base64 = Buffer.from(arrayBuffer).toString("base64");
    return `data:${contentType};base64,${base64}`;
  } catch (error) {
    console.error("Google image fetch error:", error.message);
    return null;
  }
}

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
      .describe("Optional base64-encoded image data URL (e.g., 'data:image/jpeg;base64,...'). Use this to attach a photo of the recipe."),
    fetch_image: z
      .boolean()
      .optional()
      .default(true)
      .describe("Auto-fetch an image from Google Images based on recipe title. Defaults to true. Set to false to skip."),
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
    };

    // Use provided image or fetch from Google
    let finalImageData = image_data;
    if (!finalImageData && fetch_image !== false) {
      console.error(`Fetching image for: ${title}`);
      finalImageData = await fetchGoogleImage(title);
    }

    if (finalImageData) {
      recipeData.image_data = finalImageData;
    }

    const recipe = { recipe: recipeData };

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

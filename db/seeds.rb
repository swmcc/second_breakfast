# Clear existing data
Recipe.destroy_all

# Seed data
recipes = [
  {
    title: "Spaghetti Bolognese",
    description: "A classic Italian pasta dish with rich, meaty sauce.",
    serves: 4,
    instructions: "Cook spaghetti according to package instructions. In a separate pan, sauté onions and garlic, then add minced beef. Cook until browned. Add tomato sauce, season, and simmer for 20 minutes. Serve over spaghetti.",
    prep_time: "30 minutes",
    ingredients: [
      { name: "spaghetti", quantity: 400, unit: "grams" },
      { name: "minced beef", quantity: 500, unit: "grams" },
      { name: "onion", quantity: 1, unit: "large" },
      { name: "garlic cloves", quantity: 2, unit: "cloves" },
      { name: "tomato sauce", quantity: 500, unit: "ml" }
    ],
    nutrition: {
      calories: 700,
      protein: 35,
      fat: 20,
      carbs: 90,
      fibre: 5,
      sugar: 8,
      sodium: 700
    }
  },
  {
    title: "Chicken Curry",
    description: "A fragrant curry with tender chicken pieces and aromatic spices.",
    serves: 4,
    instructions: "Sauté onions and garlic with spices. Add chicken and brown on all sides. Pour in coconut milk and simmer for 25 minutes. Serve with rice.",
    prep_time: "40 minutes",
    ingredients: [
      { name: "chicken breasts", quantity: 2, unit: "pieces" },
      { name: "onion", quantity: 1, unit: "large" },
      { name: "garlic cloves", quantity: 2, unit: "cloves" },
      { name: "coconut milk", quantity: 400, unit: "ml" },
      { name: "curry powder", quantity: 2, unit: "tbsp" }
    ],
    nutrition: {
      calories: 600,
      protein: 40,
      fat: 25,
      carbs: 50,
      fibre: 3,
      sugar: 5,
      sodium: 600
    }
  },
  {
    title: "Vegetable Stir-fry",
    description: "A quick and healthy stir-fry with fresh vegetables.",
    serves: 2,
    instructions: "Heat oil in a wok. Add vegetables and stir-fry for 5-7 minutes. Add soy sauce and stir well. Serve with noodles or rice.",
    prep_time: "20 minutes",
    ingredients: [
      { name: "mixed vegetables", quantity: 300, unit: "grams" },
      { name: "soy sauce", quantity: 2, unit: "tbsp" },
      { name: "garlic cloves", quantity: 1, unit: "clove" },
      { name: "oil", quantity: 1, unit: "tbsp" }
    ],
    nutrition: {
      calories: 300,
      protein: 8,
      fat: 10,
      carbs: 40,
      fibre: 7,
      sugar: 6,
      sodium: 900
    }
  },
  {
    title: "Pancakes",
    description: "Fluffy pancakes perfect for breakfast or brunch.",
    serves: 4,
    instructions: "Mix flour, eggs, milk, and sugar to form a batter. Heat a pan and cook pancakes on both sides until golden brown. Serve with syrup or fruit.",
    prep_time: "20 minutes",
    ingredients: [
      { name: "flour", quantity: 200, unit: "grams" },
      { name: "eggs", quantity: 2, unit: "large" },
      { name: "milk", quantity: 300, unit: "ml" },
      { name: "sugar", quantity: 1, unit: "tbsp" },
      { name: "butter", quantity: 2, unit: "tbsp" }
    ],
    nutrition: {
      calories: 500,
      protein: 12,
      fat: 18,
      carbs: 70,
      fibre: 2,
      sugar: 10,
      sodium: 400
    }
  },
  {
    title: "Caesar Salad",
    description: "A fresh salad with crispy romaine lettuce, parmesan, and croutons.",
    serves: 2,
    instructions: "Toss chopped lettuce with Caesar dressing. Add croutons and grated parmesan. Serve immediately.",
    prep_time: "15 minutes",
    ingredients: [
      { name: "romaine lettuce", quantity: 1, unit: "head" },
      { name: "Caesar dressing", quantity: 100, unit: "ml" },
      { name: "croutons", quantity: 50, unit: "grams" },
      { name: "parmesan cheese", quantity: 30, unit: "grams" }
    ],
    nutrition: {
      calories: 350,
      protein: 10,
      fat: 20,
      carbs: 30,
      fibre: 3,
      sugar: 3,
      sodium: 800
    }
  }
]

# Create recipes in the database
recipes.each do |recipe_data|
  Recipe.create!(
    title: recipe_data[:title],
    description: recipe_data[:description],
    serves: recipe_data[:serves],
    instructions: recipe_data[:instructions],
    prep_time: recipe_data[:prep_time],
    ingredients: recipe_data[:ingredients],
    nutrition: recipe_data[:nutrition]
  )
end

puts "Seeded #{Recipe.count} recipes!"
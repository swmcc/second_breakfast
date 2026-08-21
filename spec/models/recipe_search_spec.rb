require "rails_helper"

RSpec.describe Recipe, ".search" do
  let(:breakfast) { create(:category, name: "Breakfast") }
  let(:dinner) { create(:category, name: "Dinner") }

  # Deliberately nonsense tokens so Faker-generated text can never match.
  def recipe_with(title:, description: "Nothing special here", instructions: "Nothing special here", **attrs)
    create(:recipe, title: title, description: description, instructions: instructions, **attrs)
  end

  it "returns an ActiveRecord::Relation so callers can chain and paginate" do
    expect(described_class.search("anything")).to be_a(ActiveRecord::Relation)
    expect(described_class.search(nil)).to be_a(ActiveRecord::Relation)
  end

  describe "matching" do
    it "matches on title" do
      match = recipe_with(title: "Zorblewaffle Stack")
      recipe_with(title: "Plain Toast")

      expect(described_class.search("zorblewaffle")).to contain_exactly(match)
    end

    it "matches on description" do
      match = recipe_with(title: "Plain Toast", description: "A quiet zorblewaffle of a breakfast")
      recipe_with(title: "Other Toast")

      expect(described_class.search("zorblewaffle")).to contain_exactly(match)
    end

    it "matches on ingredient names inside the JSON column" do
      match = recipe_with(
        title: "Mystery Bowl",
        ingredients: [ { "name" => "Zorblewaffle", "quantity" => "2", "unit" => "cups" } ]
      )
      recipe_with(title: "Plain Toast")

      expect(described_class.search("zorblewaffle")).to contain_exactly(match)
    end

    it "matches on the ActionText instructions body" do
      match = recipe_with(title: "Mystery Bowl", instructions: "Fold the zorblewaffle through gently")
      recipe_with(title: "Plain Toast")

      expect(described_class.search("zorblewaffle")).to contain_exactly(match)
    end

    it "is case insensitive and stems the query" do
      match = recipe_with(title: "Fluffy Pancakes")

      expect(described_class.search("PANCAKE")).to contain_exactly(match)
    end

    it "requires every term in a multi-word query" do
      both = recipe_with(title: "Zorblewaffle Sundae")
      recipe_with(title: "Zorblewaffle Toast")

      expect(described_class.search("zorblewaffle sundae")).to contain_exactly(both)
    end

    it "returns nothing when nothing matches" do
      recipe_with(title: "Plain Toast")

      expect(described_class.search("zorblewaffle")).to be_empty
    end
  end

  describe "relevance ordering" do
    it "ranks a title hit above a description hit above an instructions hit" do
      in_instructions = recipe_with(title: "Third", instructions: "Add zorblewaffle at the end")
      in_description = recipe_with(title: "Second", description: "A zorblewaffle situation")
      in_title = recipe_with(title: "Zorblewaffle Supreme")

      expect(described_class.search("zorblewaffle")).to eq([ in_title, in_description, in_instructions ])
    end

    it "defaults to relevance when a query is present and no sort is given" do
      recipe_with(title: "Alpha", description: "a zorblewaffle mention")
      in_title = recipe_with(title: "Zorblewaffle Beta")

      expect(described_class.search("zorblewaffle").first).to eq(in_title)
    end
  end

  describe "category filtering" do
    it "filters by a single category" do
      match = recipe_with(title: "Eggs", category: breakfast)
      recipe_with(title: "Steak", category: dinner)

      expect(described_class.search(nil, category_ids: [ breakfast.id ])).to contain_exactly(match)
    end

    it "filters by multiple categories" do
      lunch = create(:category, name: "Lunch")
      a = recipe_with(title: "Eggs", category: breakfast)
      b = recipe_with(title: "Steak", category: dinner)
      recipe_with(title: "Sandwich", category: lunch)

      results = described_class.search(nil, category_ids: [ breakfast.id, dinner.id ])

      expect(results).to match_array([ a, b ])
    end

    it "accepts string ids from query params" do
      match = recipe_with(title: "Eggs", category: breakfast)
      recipe_with(title: "Steak", category: dinner)

      expect(described_class.search(nil, category_ids: [ breakfast.id.to_s ])).to contain_exactly(match)
    end

    it "ignores blank and non-numeric ids" do
      a = recipe_with(title: "Eggs", category: breakfast)
      b = recipe_with(title: "Steak", category: dinner)

      expect(described_class.search(nil, category_ids: [ "", "not-an-id" ])).to match_array([ a, b ])
    end

    it "combines the category filter with the text query" do
      match = recipe_with(title: "Zorblewaffle Eggs", category: breakfast)
      recipe_with(title: "Zorblewaffle Steak", category: dinner)

      expect(described_class.search("zorblewaffle", category_ids: [ breakfast.id ])).to contain_exactly(match)
    end
  end

  describe "ingredient filtering" do
    it "filters by ingredient name" do
      match = recipe_with(
        title: "Omelette",
        ingredients: [ { "name" => "Free range eggs", "quantity" => "3", "unit" => "pieces" } ]
      )
      recipe_with(
        title: "Toast",
        ingredients: [ { "name" => "Bread", "quantity" => "2", "unit" => "slices" } ]
      )

      expect(described_class.search(nil, ingredient: "eggs")).to contain_exactly(match)
    end

    it "is case insensitive and matches partial names" do
      match = recipe_with(
        title: "Omelette",
        ingredients: [ { "name" => "Free range eggs", "quantity" => "3", "unit" => "pieces" } ]
      )

      expect(described_class.search(nil, ingredient: "RANGE")).to contain_exactly(match)
    end

    it "does not match against quantities or units" do
      recipe_with(
        title: "Omelette",
        ingredients: [ { "name" => "Eggs", "quantity" => "3", "unit" => "pieces" } ]
      )

      expect(described_class.search(nil, ingredient: "pieces")).to be_empty
    end

    it "treats LIKE metacharacters literally" do
      recipe_with(
        title: "Omelette",
        ingredients: [ { "name" => "Eggs", "quantity" => "3", "unit" => "pieces" } ]
      )

      expect(described_class.search(nil, ingredient: "%")).to be_empty
    end

    it "ignores a blank ingredient filter" do
      match = recipe_with(title: "Omelette")

      expect(described_class.search(nil, ingredient: "  ")).to contain_exactly(match)
    end
  end

  describe "sorting" do
    let!(:oldest) { recipe_with(title: "Zebra zorblewaffle", created_at: 3.days.ago) }
    let!(:middle) { recipe_with(title: "apple zorblewaffle", created_at: 2.days.ago) }
    let!(:newest) { recipe_with(title: "Mango zorblewaffle", created_at: 1.day.ago) }

    it "sorts by newest" do
      expect(described_class.search("zorblewaffle", sort: "newest")).to eq([ newest, middle, oldest ])
    end

    it "sorts alphabetically, case insensitively" do
      expect(described_class.search("zorblewaffle", sort: "alphabetical")).to eq([ middle, newest, oldest ])
    end

    it "sorts by relevance when asked" do
      expect(described_class.search("zorblewaffle", sort: "relevance")).to match_array([ newest, middle, oldest ])
    end

    it "falls back to newest for an unknown sort value" do
      expect(described_class.search("zorblewaffle", sort: "sneaky sort clause")).to eq([ newest, middle, oldest ])
    end

    it "falls back to newest when relevance is requested without a query" do
      expect(described_class.search(nil, sort: "relevance")).to eq([ newest, middle, oldest ])
    end

    it "exposes the whitelist of sort options" do
      expect(described_class::SORT_OPTIONS).to eq(%w[relevance newest alphabetical])
    end
  end

  describe "blank query" do
    it "returns every recipe, newest first" do
      older = recipe_with(title: "Older", created_at: 2.days.ago)
      newer = recipe_with(title: "Newer", created_at: 1.day.ago)

      expect(described_class.search("")).to eq([ newer, older ])
      expect(described_class.search(nil)).to eq([ newer, older ])
      expect(described_class.search("   ")).to eq([ newer, older ])
    end
  end

  describe "hostile input" do
    it "treats SQL metacharacters as literal search text" do
      recipe_with(title: "Fluffy Pancakes")

      expect { described_class.search("%' OR '1'='1").to_a }.not_to raise_error
      expect(described_class.search("'; DELETE FROM recipes; --")).to be_empty
      expect(described_class.count).to eq(1)
    end

    it "does not blow up on tsquery operator characters" do
      recipe_with(title: "Fluffy Pancakes")

      expect { described_class.search("pancakes & | ! <->").to_a }.not_to raise_error
      expect { described_class.search("(((").to_a }.not_to raise_error
    end
  end
end

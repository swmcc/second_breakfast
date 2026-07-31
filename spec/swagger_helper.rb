# frozen_string_literal: true

require "rails_helper"

RSpec.configure do |config|
  config.openapi_root = Rails.root.join("swagger").to_s

  config.openapi_specs = {
    "v1/swagger.yaml" => {
      openapi: "3.0.1",
      info: {
        title: "Second Breakfast API",
        version: "v1",
        description: "API for managing recipes, categories, and meal baskets"
      },
      paths: {},
      servers: [
        {
          url: "{protocol}://{host}",
          variables: {
            protocol: { default: "http", enum: [ "http", "https" ] },
            host: { default: "localhost:3000" }
          }
        }
      ],
      components: {
        securitySchemes: {
          bearer_auth: {
            type: :http,
            scheme: :bearer,
            description: "API token authentication"
          }
        },
        schemas: {
          Recipe: {
            type: :object,
            properties: {
              id: { type: :integer },
              title: { type: :string },
              description: { type: :string },
              serves: { type: :integer },
              prep_time: { type: :string },
              ingredients: {
                type: :array,
                items: {
                  type: :object,
                  properties: {
                    name: { type: :string },
                    quantity: { type: :string },
                    unit: { type: :string }
                  }
                }
              },
              nutrition: {
                type: :object,
                properties: {
                  calories: { type: :string },
                  protein: { type: :string },
                  fat: { type: :string },
                  carbs: { type: :string },
                  fibre: { type: :string },
                  sugar: { type: :string },
                  sodium: { type: :string }
                }
              },
              instructions: { type: :string },
              category: {
                type: :object,
                properties: {
                  id: { type: :integer },
                  name: { type: :string }
                }
              },
              image_url: { type: :string, nullable: true },
              created_at: { type: :string, format: "date-time" },
              updated_at: { type: :string, format: "date-time" }
            }
          },
          Category: {
            type: :object,
            properties: {
              id: { type: :integer },
              name: { type: :string }
            }
          },
          Pagination: {
            type: :object,
            properties: {
              current_page: { type: :integer },
              total_pages: { type: :integer },
              total_count: { type: :integer },
              per_page: { type: :integer }
            }
          },
          Error: {
            type: :object,
            properties: {
              error: { type: :string }
            }
          },
          ValidationErrors: {
            type: :object,
            properties: {
              errors: {
                type: :array,
                items: { type: :string }
              }
            }
          }
        }
      }
    }
  }

  config.openapi_format = :yaml
end

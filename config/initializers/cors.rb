# frozen_string_literal: true

Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    # Defaults to permissive for local development; set CORS_ALLOWED_ORIGINS to a
    # comma-separated list of origins in production to lock this down. The bundled
    # mcp-server calls the API server-side and does not need CORS.
    origins ENV.fetch("CORS_ALLOWED_ORIGINS", "*").split(",").map(&:strip)

    resource "/api/*",
      headers: :any,
      methods: [ :get, :post, :put, :patch, :delete, :options, :head ],
      expose: [ "Authorization" ]
  end
end

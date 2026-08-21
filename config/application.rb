require_relative "boot"

require "rails"
# Pick the frameworks you want:
require "active_model/railtie"
require "active_job/railtie"
require "active_record/railtie"
require "active_storage/engine"
require "action_controller/railtie"
require "action_mailer/railtie"
require "action_mailbox/engine"
require "action_text/engine"
require "action_view/railtie"
require "action_cable/engine"
# require "rails/test_unit/railtie"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module SecondBreakfast
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.0

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    # `observability` is loaded by hand (below) rather than autoloaded, because
    # config/environments/production.rb needs the log formatter while the
    # application is still being configured.
    config.autoload_lib(ignore: %w[assets tasks observability observability.rb])

    # Observability: JSON logging, request ids, slow request/SQL warnings and
    # metric log lines. See lib/observability.rb.
    require_relative "../lib/observability"

    # Carry the request id into Observability::Current so every log line and
    # Sentry event can be traced back to a single request. Must sit after
    # ActionDispatch::RequestId (which generates the id) and after
    # ActionDispatch::Executor (which resets CurrentAttributes) - the default
    # stack orders Executor first, so inserting after RequestId satisfies both.
    config.middleware.insert_after ActionDispatch::RequestId, Observability::RequestContext

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")

    # Don't generate system test files.
    config.generators.system_tests = nil
  end
end

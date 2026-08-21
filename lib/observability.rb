# frozen_string_literal: true

require "json"
require "logger"

require_relative "observability/controller_context"
require_relative "observability/current"
require_relative "observability/json_log_formatter"
require_relative "observability/metrics"
require_relative "observability/metrics_subscriber"
require_relative "observability/performance_subscriber"
require_relative "observability/request_context"
require_relative "observability/request_log_subscriber"
require_relative "observability/sentry_scrubber"

# Observability is a small, self-contained instrumentation layer:
#
#   * `Observability::JsonLogFormatter`      - line-delimited JSON logs on STDOUT
#   * `Observability::RequestLogSubscriber`  - one summary log line per request
#   * `Observability::PerformanceSubscriber` - slow request / slow SQL warnings
#   * `Observability::MetricsSubscriber`     - `metric` log lines for key actions
#   * `Observability::SentryScrubber`        - PII scrubbing for Sentry events
#
# Everything is opt-in through ENV and attached from
# `config/initializers/observability.rb`, so the whole layer can be removed by
# deleting `lib/observability*` plus that one initializer.
module Observability
  DEFAULT_SLOW_REQUEST_MS    = 1_000
  DEFAULT_SLOW_QUERY_MS      = 500
  DEFAULT_TRACES_SAMPLE_RATE = 0.05

  # Anything matching these is stripped before an event leaves the process.
  SENSITIVE_KEY_PATTERNS = [
    /password/i,
    /password_confirmation/i,
    /token/i,
    /api[_-]?key/i,
    /authorization/i
  ].freeze

  class << self
    # Attach the notification subscribers. Off outside production unless
    # OBSERVABILITY_ENABLED is set, so local development and the test suite
    # stay quiet.
    def enabled?
      env_flag("OBSERVABILITY_ENABLED", Rails.env.production?)
    end

    # Line-delimited JSON on STDOUT. Production by default; opt in elsewhere
    # with RAILS_LOG_FORMAT=json, opt out in production with
    # RAILS_LOG_FORMAT=text.
    def json_logging?
      ENV.fetch("RAILS_LOG_FORMAT", Rails.env.production? ? "json" : "text").to_s.downcase == "json"
    end

    # True when a DSN was supplied, i.e. when config/initializers/sentry.rb
    # will configure the client at all.
    def sentry_enabled?
      ENV["SENTRY_DSN"].present?
    end

    # True only once Sentry has actually been initialised, which is what the
    # instrumentation checks before touching the Sentry API.
    def sentry_reporting?
      defined?(::Sentry) && ::Sentry.initialized?
    end

    def slow_request_threshold_ms
      float_env("SLOW_REQUEST_MS", DEFAULT_SLOW_REQUEST_MS)
    end

    def slow_query_threshold_ms
      float_env("SLOW_QUERY_MS", DEFAULT_SLOW_QUERY_MS)
    end

    def traces_sample_rate
      float_env("SENTRY_TRACES_SAMPLE_RATE", DEFAULT_TRACES_SAMPLE_RATE)
    end

    def log_formatter
      json_logging? ? JsonLogFormatter.new : ActiveSupport::Logger::SimpleFormatter.new
    end

    # Build the application logger. JSON logs are deliberately not wrapped in
    # TaggedLogging: the `[request-id]` tag would be baked into the message
    # string. The request id is emitted as a first-class `request_id` field
    # instead (see JsonLogFormatter).
    def build_logger(io = $stdout)
      io.sync = true if io.respond_to?(:sync=)
      logger = ActiveSupport::Logger.new(io)
      logger.formatter = log_formatter
      json_logging? ? logger : ActiveSupport::TaggedLogging.new(logger)
    end

    def logger
      Rails.logger
    end

    def parameter_filter
      @parameter_filter ||= ActiveSupport::ParameterFilter.new(SENSITIVE_KEY_PATTERNS)
    end

    # Instrumentation must never break a request or a job. Anything that goes
    # wrong inside a subscriber is downgraded to a debug line.
    def report_instrumentation_error(error)
      Rails.logger&.debug { "observability instrumentation error: #{error.class}: #{error.message}" }
      nil
    end

    private

    def float_env(name, default)
      value = ENV[name]
      value.nil? || value.empty? ? default.to_f : value.to_f
    end

    def env_flag(name, default)
      value = ENV[name]
      return default if value.nil? || value.empty?

      ActiveModel::Type::Boolean.new.cast(value) || false
    end
  end
end
